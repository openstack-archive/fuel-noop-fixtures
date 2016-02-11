module Noop
  class Task
    def setup_overrides
      # puppet_default_settings
      hiera_config_override
      puppet_debug_override if ENV['SPEC_PUPPET_DEBUG']
      setup_manifest
      puppet_resource_scope_override
    end

    def setup_manifest
      RSpec.configuration.manifest = file_path_manifest.to_s
      RSpec.configuration.module_path = Noop::Config.dir_path_modules_local.to_s
      RSpec.configuration.manifest_dir = Noop::Config.dir_path_tasks_local.to_s
    end

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
      Puppet.settings.initialize_app_defaults(
          {
              :logdir => '/dev/null',
              :confdir => '/dev/null',
              :vardir => '/dev/null',
              :rundir => '/dev/null',
              :hiera_config => '/dev/null',
          }
      )
    end

  end
end
