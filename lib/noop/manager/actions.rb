require 'parallel'

module Noop
  class Manager
    def find_tasks_without_specs
      task_file_names.reject do |manifest|
        spec = Noop::Utils.convert_to_spec manifest
        spec_file_names.include? spec
      end
    end

    def debug(message)
      Noop::Config.log.debug message
    end

    def output(message)
      puts message
    end

    def parallel_run?
      options[:parallel_run] and options[:parallel_run] > 0
    end

    def list_hiera_files
      hiera_file_names.sort.each do |file_name_hiera|
        next unless hiera_included? file_name_hiera
        output file_name_hiera
      end
      exit(0)
    end

    def list_facts_files
      facts_file_names.sort.each do |file_name_facts|
        next unless facts_included? file_name_facts
        output file_name_facts
      end
      exit(0)
    end

    def list_spec_files
      spec_file_names.sort.each do |file_name_spec|
        next unless spec_included? file_name_spec
        output file_name_spec
      end
      exit(0)
    end

    def list_task_files
      task_file_names.sort.each do |file_name_task|
        output file_name_task
      end
      exit(0)
    end

    def run_all_tasks
      Parallel.map(task_list, :in_threads => options[:parallel_run]) do |task|
        task.run unless options[:pretend]
        task
      end
    end

    def run_failed_tasks
      Parallel.map(task_list, :in_threads => options[:parallel_run]) do |task|
        next if task.success?
        task.status = :pending
        task.run unless options[:pretend]
        task
      end
    end

    def load_task_reports
      Parallel.map(task_list, :in_threads => options[:parallel_run]) do |task|
        task.file_load_report_json
        task.determine_task_status
        task
      end
    end

    def list_tasks_without_specs
      tasks_without_specs = find_tasks_without_specs.to_a
      if tasks_without_specs.any?
        Noop::Utils.error "There are tasks without specs: #{tasks_without_specs.join ', '}"
      end
    end

    def have_failed_tasks?
      task_list.any? do |task|
        task.failed?
      end
    end

    def exit_with_error_code
      exit 1 if have_failed_tasks?
      exit 0
    end

#########################################

    def main
      options

      if ENV['SPEC_TASK_CONSOLE']
        require 'pry'
        binding.pry
        exit(0)
      end

      if options[:list_missing]
        list_tasks_without_specs
      end

      if options[:bundle_setup]
        setup_bundle
      end

      if options[:update_librarian_puppet]
        setup_library
      end

      if options[:self_check]
        check_paths
        show_filters
        show_library
        exit(0)
      end

      list_hiera_files if options[:list_hiera]
      list_facts_files if options[:list_facts]
      list_spec_files if options[:list_specs]
      list_task_files if options[:list_tasks]

      if options[:run_failed_tasks]
        load_task_reports
        run_failed_tasks
        task_report
        exit_with_error_code
      end

      if options[:load_saved_reports]
        load_task_reports
        task_report
        save_xunit_report if options[:xunit_report]
        exit_with_error_code
      end

      run_all_tasks
      task_report
      save_xunit_report if options[:xunit_report]
      exit_with_error_code
    end

  end
end
