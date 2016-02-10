require 'erb'
require 'colorize'
require 'rexml/document'

module Noop
  class Manager
    STATUS_STRING_LENGTH = 8

    def tasks_report_structure(tasks)
      tasks_report = []

      tasks.each do |task|
        task_hash = {}
        task_hash[:status] = task.status
        task_hash[:name] = task.to_s
        task_hash[:description] = task.description
        task_hash[:spec] = task.file_name_spec.to_s
        task_hash[:hiera] = task.file_name_hiera.to_s
        task_hash[:facts] = task.file_name_facts.to_s
        task_hash[:task] = task.file_name_manifest.to_s
        task_hash[:examples] = []

        if task.report.is_a? Hash
          examples = task.report['examples']
          next unless examples.is_a? Array
          examples.each do |example|
            example_hash = {}
            example_hash[:file_path] = example['file_path']
            example_hash[:line_number] = example['line_number']
            example_hash[:description] = example['description']
            example_hash[:status] = example['status']
            example_hash[:run_time] = example['run_time']
            example_hash[:pending_message] = example['pending_message']
            exception_class = example.fetch('exception', {}).fetch('class', nil)
            exception_message = example.fetch('exception', {}).fetch('message', nil)
            next unless example_hash[:description] and example_hash[:status]
            if exception_class and exception_message
              example_hash[:exception_class] = exception_class
              example_hash[:exception_message] = exception_message
            end
            task_hash[:examples] << example_hash
          end

          summary = task.report['summary']
          task_hash[:example_count] = summary['example_count']
          task_hash[:failure_count] = summary['failure_count']
          task_hash[:pending_count] = summary['pending_count']
          task_hash[:duration] = summary['duration']
        end

        tasks_report << task_hash
      end
      tasks_report
    end

    def output_task_status(task)
      return if options[:report_only_failed] and task.success?
      line = task_status_string task
      line += "#{task.file_base_spec.to_s.ljust max_length_spec + 1}"
      line += "#{task.file_base_facts.to_s.ljust max_length_facts + 1}"
      line += "#{task.file_base_hiera.to_s.ljust max_length_hiera + 1}"
      output line
      output_task_examples task
    end

    def output_task_examples(task)
      return unless task.report.is_a? Hash
      examples = task.report['examples']
      return unless examples.is_a? Array
      examples.each do |example|
        description = example['description']
        status = example['status']
        next unless description and status
        next if options[:report_only_failed] and status == 'passed'
        line = "  #{example_status_string status} #{description}"
        exception_message = example.fetch('exception', {}).fetch('message', nil)
        line += " (#{exception_message.colorize :cyan})" if exception_message
        output line
      end
    end

    def task_status_string(task)
      if task.pending?
        'PENDING'.ljust(STATUS_STRING_LENGTH).colorize :blue
      elsif task.success?
        'SUCCESS'.ljust(STATUS_STRING_LENGTH).colorize :green
      elsif task.failed?
        'FAILED'.ljust(STATUS_STRING_LENGTH).colorize :red
      else
        task.status
      end
    end

    def example_status_string(status)
      if status == 'passed'
        status.ljust(STATUS_STRING_LENGTH).colorize :green
      elsif status == 'failed'
        status.ljust(STATUS_STRING_LENGTH).colorize :red
      else
        status.ljust(STATUS_STRING_LENGTH).colorize :blue
      end
    end

    def directory_check_status_string(directory)
      if directory.directory?
        'SUCCESS'.ljust(STATUS_STRING_LENGTH).colorize :green
      else
        'FAILED'.ljust(STATUS_STRING_LENGTH).colorize :red
      end
    end

    def max_length_spec
      return @max_length_spec if @max_length_spec
      @max_length_spec = task_list.map do |task|
        task.file_base_spec.to_s.length
      end.max
    end

    def max_length_hiera
      return @max_length_hiera if @max_length_hiera
      @max_length_hiera = task_list.map do |task|
        task.file_base_hiera.to_s.length
      end.max
    end

    def max_length_facts
      return @max_length_facts if @max_length_facts
      @max_length_facts = task_list.map do |task|
        task.file_base_facts.to_s.length
      end.max
    end

    def task_report
      task_list.each do |task|
        output_task_status task
      end
    end

    def show_filters
      if options[:filter_specs]
        options[:filter_specs] = [options[:filter_specs]] unless options[:filter_specs].is_a? Array
        output "Spec filter: #{options[:filter_specs].join ', '}"
      end
      if options[:filter_facts]
        options[:filter_facts] = [options[:filter_facts]] unless options[:filter_facts].is_a? Array
        output "Facts filter: #{options[:filter_facts].join ', '}"
      end
      if options[:filter_hiera]
        options[:filter_hiera] = [options[:filter_hiera]] unless options[:filter_hiera].is_a? Array
        output "Hiera filter: #{options[:filter_hiera].join ', '}"
      end
      if options[:filter_examples]
        options[:filter_examples] = [options[:filter_examples]] unless options[:filter_examples].is_a? Array
        output "Examples filter: #{options[:filter_examples].join ', '}"
      end
    end

    def show_library
      template = <<-'eof'
<%= '=' * 80 %>
Tasks discovered: <%= task_file_names.length %>
Specs discovered: <%= spec_file_names.length %>
Hiera discovered: <%= hiera_file_names.length %>
Facts discovered: <%= facts_file_names.length %>
Tasks in graph metadata:  <%= task_graph_metadata.length %>
Tasks with spec metadata: <%= spec_run_metadata.length %>
Total tasks to run: <%= task_list.count %>
      eof
      output ERB.new(template, nil, '-').result(binding)
    end

    def check_paths
      paths = [
          :dir_path_config,
          :dir_path_root,
          :dir_path_task_spec,
          :dir_path_modules_local,
          :dir_path_tasks_local,
          :dir_path_deployment,
          :dir_path_workspace,
          :dir_path_hiera,
          :dir_path_hiera_override,
          :dir_path_facts,
          :dir_path_facts_override,
          :dir_path_globals,
          :dir_path_reports,
      ]
      max_length = paths.map { |p| p.to_s.length }.max
      paths.each do |path|
        directory = Noop::Config.send path
        output "#{directory_check_status_string directory} #{path.to_s.ljust max_length} #{directory}"
      end
    end

  end
end
