module Noop
  class Task
    # Setup all needed override functions
    def setup_overrides
      puppet_default_settings
      puppet_debug_override if ENV['SPEC_PUPPET_DEBUG']
      puppet_resource_scope_override
      rspec_coverage_add_override
      return unless file_name_spec_set?
      hiera_config_override
      setup_manifest
    end

    # Set the current module path and the manifest file
    # to run in this RSpec session
    def setup_manifest
      RSpec.configuration.manifest = file_path_manifest.to_s
      RSpec.configuration.module_path = Noop::Config.list_path_modules.join ':'
      RSpec.configuration.manifest_dir = Noop::Config.dir_path_tasks_local.to_s

      # FIXME: kludge to support calling Puppet function outside of the test context
      Puppet.settings[:modulepath] = RSpec.configuration.module_path
      Puppet.settings[:manifest] = RSpec.configuration.manifest_dir
    end

    # Override Hiera configuration in the Puppet objects
    def hiera_config_override
      class << HieraPuppet
        def hiera
          @hiera ||= Hiera.new(:config => hiera_config)
          Hiera.logger = 'noop'
          @hiera
        end
      end

      class << Hiera::Config
        def config
          @config
        end

        def config=(value)
          @config = value
        end

        def load(source)
          @config ||= {}
        end

        def yaml_load_file(source)
          @config ||= {}
        end

        def []=(key, value)
          @config ||= {}
          @config[key] = value
        end
      end
      Hiera::Config.config = hiera_config
    end

    # Ask Puppet to save the current scope reference to the task instance
    def puppet_resource_scope_override
      Puppet::Parser::Resource.module_eval do
        def initialize(*args)
          raise ArgumentError, "Resources require a hash as last argument" unless args.last.is_a? Hash
          raise ArgumentError, "Resources require a scope" unless args.last[:scope]
          super
          Noop.task.puppet_scope = scope
          @source ||= scope.source
        end
      end
    end

    # Divert Puppet logs to the console
    def puppet_debug_override
      Puppet::Util::Log.level = :debug
      Puppet::Util::Log.newdestination(:console)
    end

    # These settings are pulled from the Puppet TestHelper
    # (See Puppet::Test::TestHelper.initialize_settings_before_each)
    # These items used to be setup in puppet 3.4 but were moved to before tests
    # which breaks our testing framework because we attempt to call
    # PuppetlabsSpec::PuppetInternals.scope and
    # Puppet::Parser::Function.autoload.load prior to the testing being run.
    # This results in an rspec failure so we need to initialize the basic
    # settings up front to prevent issues with test framework. See PUP-5601
    def puppet_default_settings
      defaults = {
          :logdir => '/dev/null',
          :confdir => '/dev/null',
          :vardir => '/dev/null',
          :rundir => '/dev/null',
          :hiera_config => '/dev/null',
      }
      defaults[:codedir] = '/dev/null' if puppet4?
      Puppet.settings.initialize_app_defaults(defaults)
    end

    def rspec_coverage_add_override
      RSpec::Puppet::Coverage.class_eval do
        def add_from_catalog(catalog, test_module)
          catalog.to_a.each do |resource|
            next if @filters.include?(resource.to_s)
            if resource.file == Puppet[:manifest]
              add(resource)
            else
              @excluded = [] unless @excluded
              @excluded << resource.to_s
            end
          end
        end
        
        def report!
          report = {}
          report[:total] = @collection.size
          report[:touched] = @collection.count { |_, resource| resource.touched? }
          report[:untouched] = report[:total] - report[:touched]
          report[:coverage] = "%5.2f" % ((report[:touched].to_f / report[:total].to_f) * 100)
          report[:resources] = Hash[*@collection.map do |name, wrapper|
            [name, wrapper.to_hash]
          end.flatten]
          report[:excluded] = @excluded
          report
        end
      end
    end

  end
end
