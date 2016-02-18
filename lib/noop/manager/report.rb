require 'erb'
require 'colorize'

module Noop
  class Manager
    COLUMN_WIDTH = 8

    # Output a status string for this task.
    # Output examples to unless disables.
    # @param task [Noop::Task]
    def output_task_status(task)
      return if options[:report_only_failed] and task.success?
      line = task_status_string task
      line += "#{task.file_base_spec.to_s.ljust max_length_spec + 1}"
      line += "#{task.file_base_facts.to_s.ljust max_length_facts + 1}"
      line += "#{task.file_base_hiera.to_s.ljust max_length_hiera + 1}"
      output line
      output_task_examples task unless options[:report_only_tasks]
    end

    # Output examples report for this task
    # @param task [Noop::Task]
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

    # Get a colored string with status of this task
    # @param task [Noop::Task]
    # @return [String]
    def task_status_string(task)
      if task.pending?
        'PENDING'.ljust(COLUMN_WIDTH).colorize :blue
      elsif task.success?
        'SUCCESS'.ljust(COLUMN_WIDTH).colorize :green
      elsif task.failed?
        'FAILED'.ljust(COLUMN_WIDTH).colorize :red
      else
        task.status
      end
    end

    # Colorize the example status string
    # @param status [String]
    # @return [String]
    def example_status_string(status)
      if status == 'passed'
        status.ljust(COLUMN_WIDTH).colorize :green
      elsif status == 'failed'
        status.ljust(COLUMN_WIDTH).colorize :red
      else
        status.ljust(COLUMN_WIDTH).colorize :blue
      end
    end

    # Return a string showing if the directory is present.
    # @param directory [Pathname]
    # @return [String]
    def directory_check_status_string(directory)
      if directory.directory?
        'SUCCESS'.ljust(COLUMN_WIDTH).colorize :green
      else
        'FAILED'.ljust(COLUMN_WIDTH).colorize :red
      end
    end

    # Find the length of the longest spec file name
    # @return [Integer]
    def max_length_spec
      return @max_length_spec if @max_length_spec
      @max_length_spec = task_list.map do |task|
        task.file_base_spec.to_s.length
      end.max
    end

    # Find the length of the longest Hiera file name
    # @return [Integer]
    def max_length_hiera
      return @max_length_hiera if @max_length_hiera
      @max_length_hiera = task_list.map do |task|
        task.file_base_hiera.to_s.length
      end.max
    end

    # Find the length of the longest facts file name
    # @return [Integer]
    def max_length_facts
      return @max_length_facts if @max_length_facts
      @max_length_facts = task_list.map do |task|
        task.file_base_facts.to_s.length
      end.max
    end

    # Output a status string with tasks count
    def output_task_totals
      count = {
          :total => 0,
          :failed => 0,
          :pending => 0,
      }
      task_list.each do |task|
        next unless task.is_a? Noop::Task
        count[:pending] += 1 if task.pending?
        count[:failed] += 1 if task.failed?
        count[:total] += 1
      end
      output_stats_string 'Tasks', count[:total], count[:failed], count[:pending]
    end

    # Output a status string with examples count
    def output_examples_total
      count = {
          :total => 0,
          :failed => 0,
          :pending => 0,
      }
      task_list.each do |task|
        next unless task.is_a? Noop::Task
        next unless task.has_report?
        task.report['examples'].each do |example|
          count[:total] += 1
          if example['status'] == 'failed'
            count[:failed] += 1
          elsif example['status'] == 'pending'
            count[:pending] += 1
          end
        end
      end
      output_stats_string 'Examples', count[:total], count[:failed], count[:pending]
    end

    # Format a status string of examples or tasks
    def output_stats_string(name, total, failed, pending)
      line = "#{name.to_s.ljust(COLUMN_WIDTH).colorize :yellow}"
      line += " Total: #{total.to_s.ljust(COLUMN_WIDTH).colorize :green}"
      line += " Failed: #{failed.to_s.ljust(COLUMN_WIDTH).colorize :red}"
      line += " Pending: #{pending.to_s.ljust(COLUMN_WIDTH).colorize :blue}"
      output line
    end

    # Show the main tasks report
    def tasks_report
      output Noop::Utils.separator
      task_list.each do |task|
        output_task_status task
      end
      output Noop::Utils.separator
      tasks_stats
      output Noop::Utils.separator
    end

    # Show the tasks and examples stats
    def tasks_stats
      output_examples_total unless options[:report_only_tasks]
      output_task_totals
    end

    # Show report with all defined filters content
    def show_filters
      if options[:filter_specs]
        options[:filter_specs] = [options[:filter_specs]] unless options[:filter_specs].is_a? Array
        output "Spec filter: #{options[:filter_specs].join(', ').colorize :green}"
      end
      if options[:filter_facts]
        options[:filter_facts] = [options[:filter_facts]] unless options[:filter_facts].is_a? Array
        output "Facts filter: #{options[:filter_facts].join(', ').colorize :green}"
      end
      if options[:filter_hiera]
        options[:filter_hiera] = [options[:filter_hiera]] unless options[:filter_hiera].is_a? Array
        output "Hiera filter: #{options[:filter_hiera].join(', ').colorize :green}"
      end
      if options[:filter_examples]
        options[:filter_examples] = [options[:filter_examples]] unless options[:filter_examples].is_a? Array
        output "Examples filter: #{options[:filter_examples].join(', ').colorize :green}"
      end
    end

    # Show the stats of discovered library objects
    def show_library
      template = <<-'eof'
Tasks discovered: <%= task_file_names.length.to_s.colorize :green %>
Specs discovered: <%= spec_file_names.length.to_s.colorize :green %>
Hiera discovered: <%= hiera_file_names.length.to_s.colorize :green %>
Facts discovered: <%= facts_file_names.length.to_s.colorize :green %>

Tasks in graph metadata:  <%= task_graph_metadata.length.to_s.colorize :yellow %>
Tasks with spec metadata: <%= spec_run_metadata.length.to_s.colorize :yellow %>
Total tasks to run:       <%= task_list.count.to_s.colorize :yellow %>
      eof
      output ERB.new(template, nil, '-').result(binding)
    end

    # Check the existence of main directories
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

    # Run all diagnostic procedures
    def self_check
      output Noop::Utils.separator
      check_paths
      output Noop::Utils.separator
      show_filters
      output Noop::Utils.separator
      show_library
      output Noop::Utils.separator
    end

  end
end
