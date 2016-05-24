module Noop
  class Manager
    def initialize
      options
      colorize_load_or_stub
      parallel_load_or_stub
    end

    # Load the "colorize" gem or just
    # stub the colorization method if the gem
    # cannot be loaded and don't show colors
    def colorize_load_or_stub
      begin
        require 'colorize'
      rescue LoadError
        debug 'Could not load "colorize" gem. Disabling colors.'
        String.instance_eval do
          define_method(:colorize) do |*args|
            self
          end
        end
      end
    end

    # Load the 'parallel' gem or just
    # stub the parallel run function to run tasks one by one
    def parallel_load_or_stub
      begin
        require 'parallel'
      rescue LoadError
        debug 'Could not load "parallel" gem. Disabling multi-process run.'
        Object.const_set('Parallel', Module.new)
        class << Parallel
          def map(data, *args, &block)
            data.map &block
          end
          def processor_count
            0
          end
        end
      end
    end

    # Write a debug message to the logger
    # @return [void]
    def debug(message)
      Noop::Config.log.debug message
    end

    # Output a message to the console
    # @return [void]
    def output(message)
      Noop::Utils.output message
    end

    # Output an error message to the log file
    # and raise the exception
    # @return [void]
    def error(message)
      Noop::Utils.error message
    end

    # Get the parallel run count value from the options
    # or from the processor count if "auto" is set
    # @return [Integer]
    def parallel_run
      return @parallel_run if @parallel_run
      if options[:parallel_run] == 'auto'
        @parallel_run = Parallel.processor_count
        debug "Using parallel run count: #{@parallel_run}"
        return @parallel_run
      end
      @parallel_run = options[:parallel_run].to_i
    end

    # Check if the parallel run option is enabled
    # @return [true,false]
    def parallel_run?
      parallel_run > 0
    end

    # Check if there are some filters defined
    # @return [true,false]
    def has_filters?
      options[:filter_specs] or options[:filter_facts] or options[:filter_hiera] or options[:filter_examples]
    end

    # Output a list of all discovered Hiera file names taking filers into account
    # @return [void]
    def list_hiera_files
      hiera_file_names.sort.each do |file_name_hiera|
        next unless hiera_included? file_name_hiera
        output file_name_hiera
      end
      exit(0)
    end

    # Output a list of all discovered facts file names taking filers into account
    # @return [void]
    def list_facts_files
      facts_file_names.sort.each do |file_name_facts|
        next unless facts_included? file_name_facts
        output file_name_facts
      end
      exit(0)
    end

    # Output a list of all discovered spec file names taking filers into account
    # @return [void]
    def list_spec_files
      spec_file_names.sort.each do |file_name_spec|
        next unless spec_included? file_name_spec
        output file_name_spec
      end
      exit(0)
    end

    # Output a list of all discovered task file names taking filers into account
    # @return [void]
    def list_task_files
      task_file_names.sort.each do |file_name_task|
        output file_name_task
      end
      exit(0)
    end

    # Try to run all discovered tasks in the task list, using
    # parallel run if enabled
    # Does not run tasks if :pretend option is given
    # return [Array<Noop::Task>]
    def run_all_tasks
      Parallel.map(task_list, :in_threads => parallel_run) do |task|
        task.run unless options[:pretend]
        task
      end
    end

    # Try to run anly those tasks that have failed status by reseting them
    # to the :pending status first.
    # Does not run tasks if :pretend option is given
    # return [Array<Noop::Task>]
    def run_failed_tasks
      Parallel.map(task_list, :in_threads => parallel_run) do |task|
        next if task.success?
        task.status = :pending
        task.run unless options[:pretend]
        task
      end
    end

    # Ask every task in the task list to load its report file and status
    # from the previous run attempt
    # return [Array<Noop::Task>]
    def load_task_reports
      Parallel.map(task_list, :in_threads => parallel_run) do |task|
        task.file_load_report_json
        task.determine_task_status
        task
      end
    end

    # Check if there are any failed tasks in the list.
    # @return [true, false]
    def have_failed_tasks?
      task_list.any? do |task|
        task.failed?
      end
    end

    # Exit with error if there are failed tasks
    # or without the error code if none.
    def exit_with_error_code
      exit 1 if have_failed_tasks?
      exit 0
    end

#########################################

    def main(override_options = {})
      options.merge! override_options

      if ENV['SPEC_TASK_CONSOLE']
        require 'pry'
        binding.pry
        exit(0)
      end

      if options[:bundle_setup]
        setup_bundle
      end

      if options[:update_librarian_puppet]
        setup_library
      end

      if options[:self_check]
        self_check
        exit(0)
      end

      list_hiera_files if options[:list_hiera]
      list_facts_files if options[:list_facts]
      list_spec_files if options[:list_specs]
      list_task_files if options[:list_tasks]

      if options[:run_failed_tasks]
        load_task_reports
        run_failed_tasks
        tasks_report
        exit_with_error_code
      end

      if options[:load_saved_reports]
        load_task_reports
        tasks_report
        save_xunit_report if options[:xunit_report] and not options[:pretend]
        exit_with_error_code
      end

      run_all_tasks
      tasks_report
      save_xunit_report if options[:xunit_report] and not options[:pretend]
      exit_with_error_code
    end

  end
end
