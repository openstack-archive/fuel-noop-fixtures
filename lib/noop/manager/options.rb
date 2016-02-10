require 'optparse'

module Noop
  class Manager

    def options
      return @options if @options
      @options = {}
      options_defaults @options

      optparse = OptionParser.new do |opts|
        opts.separator 'Main options:'
        opts.on('-j', '--jobs JOBS', 'Parallel run RSpec jobs') do |jobs|
          @options[:parallel_run] = jobs.to_i
        end
        opts.on('-g', '--globals', 'Run all globals tasks and update saved globals YAML files') do |jobs|
          ENV['SPEC_UPDATE_GLOBALS'] = 'YES'
          options[:filter_specs] = [Noop::Config.spec_name_globals]
        end
        opts.on('-b', '--bundle_setup', 'Setup Ruby environment using Bundle') do
          @options[:bundle_setup] = true
        end
        opts.on('-B', '--bundle_exec', 'Use "bundle exec" to run rspec') do
          ENV['SPEC_BUNDLE_EXEC'] = 'YES'
        end
        opts.on('-l', '--update-librarian', 'Run librarian-puppet update in the deployment directory prior to testing') do
          @options[:update_librarian_puppet] = true
        end
        opts.on('-L', '--reset-librarian', 'Reset puppet modules to librarian versions in the deployment directory prior to testing') do
          @options[:reset_librarian_puppet] = true
        end
        opts.on('-o', '--report_only_failed', 'Show only failed tasks and examples in the report') do
          @options[:report_only_failed] = true
        end
        opts.on('-r', '--load_saved_reports', 'Read saved report JSON files from the previous run and show tasks report') do
          @options[:load_saved_reports] = true
        end
        opts.on('-R', '--run_failed_tasks', 'Run the task that have previously failed again') do
          @options[:run_failed_tasks] = true
        end
        opts.on('-M', '--list_missing', 'List all task manifests without a spec file') do
          @options[:list_missing] = true
        end
        opts.on('-x', '--xunit_report', 'Save report in xUnit format to a file') do
          @options[:xunit_report] = true
        end

        opts.separator 'List options:'
        opts.on('-Y', '--list_hiera', 'List all hiera yaml files') do
          @options[:list_hiera] = true
        end
        opts.on('-S', '--list_specs', 'List all task spec files') do
          @options[:list_specs] = true
        end
        opts.on('-F', '--list_facts', 'List all facts yaml files') do
          @options[:list_facts] = true
        end
        opts.on('-T', '--list_tasks', 'List all task manifest files') do
          @options[:list_tasks] = true
        end

        opts.separator 'Filter options:'
        opts.on('-s', '--specs SPEC1,SPEC2', Array, 'Run only these spec files. Example: "hosts/hosts_spec.rb,apache/apache_spec.rb"') do |specs|
          @options[:filter_specs] = import_specs_list specs
        end
        opts.on('-y', '--yamls YAML1,YAML2', Array, 'Run only these hiera yamls. Example: "controller.yaml,compute.yaml"') do |yamls|
          @options[:filter_hiera] = import_yamls_list yamls
        end
        opts.on('-f', '--facts FACTS1,FACTS2', Array, 'Run only these facts yamls. Example: "ubuntu.yaml,centos.yaml"') do |yamls|
          @options[:filter_facts] = import_yamls_list yamls
        end
        # opts.on('-e', '--examples STR1,STR2', Array, 'Run only these spec examples. Example: "should compile"') do |examples|
        #   @options[:filter_examples] = examples
        # end

        opts.separator 'Debug options:'
        opts.on('-c', '--task_console', 'Run PRY console') do
          ENV['SPEC_TASK_CONSOLE'] = 'YES'
        end
        opts.on('-C', '--rspec_console', 'Run PRY console in the ') do
          ENV['SPEC_RSPEC_CONSOLE'] = 'YES'
        end
        opts.on('-d', '--task_debug', 'Show framework debug messages') do
          ENV['SPEC_TASK_DEBUG'] = 'YES'
        end
        opts.on('-D', '--puppet_debug', 'Show Puppet debug messages') do
          ENV['SPEC_PUPPET_DEBUG'] = 'YES'
        end
        opts.on('--debug_log FILE', 'Write all debug messages to this files') do |file|
          ENV['SPEC_DEBUG_LOG'] = file
        end
        opts.on('-t', '--self-check', 'Perform self-check and diagnostic procedures') do
          @options[:self_check] = true
        end
        opts.on('-p', '--pretend', 'Show which tasks will be run without actually running them') do
          @options[:pretend] = true
        end

        opts.separator 'Path options:'
        opts.on('--dir_root DIR', 'Path to the test root folder') do |dir|
          ENV['SPEC_ROOT_DIR'] = dir
        end
        opts.on('--dir_deployment DIR', 'Path to the test deployment folder') do |dir|
          ENV['SPEC_DEPLOYMENT_DIR'] = dir
        end
        opts.on('--dir_hiera_yamls DIR', 'Path to the folder with hiera files') do |dir|
          ENV['SPEC_HIERA_DIR'] = dir
        end
        opts.on('--dir_facts_yamls DIR', 'Path to the folder with facts yaml files') do |dir|
          ENV['SPEC_FACTS_DIR'] = dir
        end
        opts.on('--dir_spec_files DIR', 'Path to the folder with task spec files (changing this may break puppet-rspec)') do |dir|
          ENV['SPEC_SPEC_DIR'] = dir
        end
        opts.on('--dir_task_files DIR', 'Path to the folder with task manifest files') do |dir|
          ENV['SPEC_TASK_DIR'] = dir
        end
        opts.on('--dir_puppet_modules DIR', 'Path to the puppet modules') do |dir|
          ENV['SPEC_MODULE_PATH'] = dir
        end

        opts.separator 'Spec options:'
        opts.on('-A', '--catalog_show', 'Show catalog content debug output') do
          ENV['SPEC_CATALOG_SHOW'] = 'YES'
        end
        # opts.on('--catalog_save', 'Save catalog to the files instead of comparing them with the current catalogs') do
        #   ENV['SPEC_CATALOG_CHECK'] = 'save'
        # end
        # opts.on('--catalog_check', 'Check the saved catalog against the current one') do
        #   ENV['SPEC_CATALOG_CHECK'] = 'check'
        # end
        # opts.on('--spec_generate', 'Generate specs for catalogs') do
        #   ENV['SPEC_SPEC_GENERATE'] = 'YES'
        # end
        opts.on('-a', '--spec_status', 'Show spec status blocks') do
          ENV['SPEC_SHOW_STATUS'] = 'YES'
        end
        # opts.on('--spec_coverage', 'Show spec coverage statistics') do
        #   ENV['SPEC_COVERAGE'] = 'YES'
        # end
        # opts.on('--puppet_binary_files', 'Check if Puppet installs binary files') do
        #   ENV['SPEC_PUPPET_BINARY_FILES'] = 'YES'
        # end
        # opts.on('--file_resources DIR', 'Save file resources to this dir') do |dir|
        #   ENV['SPEC_SAVE_FILE_RESOURCES'] = dir
        # end

      end
      optparse.parse!
      @options
    end

    def import_specs_list(specs)
      specs.map do |spec|
        Noop::Utils.convert_to_spec spec
      end
    end

    def import_yamls_list(yamls)
      yamls.map do |yaml|
        Noop::Utils.convert_to_yaml yaml
      end
    end

    def options_defaults(options)
      options[:parallel_run] = 0
    end

  end
end
