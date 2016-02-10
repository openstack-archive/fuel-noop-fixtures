require 'json'

module Noop
  class Task
    def run
      return unless pending?
      self.pid = Process.pid
      self.thread = Thread.current.object_id
      Noop::Utils.debug "RUN: #{self.inspect}"
      file_remove_report_json
      rspec_command_run
      file_load_report_json
      determine_task_status
      Noop::Utils.debug "FINISH: #{self.inspect}"
      status
    end

    def file_load_report_json
      self.report = file_data_report_json
    end

    def set_status_value(value)
      if value.is_a? TrueClass
        self.status = :success
      elsif value.is_a? FalseClass
        self.status = :failed
      else
        self.status = :pending
      end
    end

    def determine_task_status
      if report.is_a? Hash
        failures = report.fetch('summary', {}).fetch('failure_count', nil)
        if failures.is_a? Numeric
          set_status_value(failures == 0)
        end
      end
      status
    end

    # @return [Pathname]
    def file_name_report_json
      Noop::Utils.convert_to_path "#{file_name_task_extension.sub_ext ''}_#{file_base_hiera}_#{file_base_facts}.json"
    end

    # @return [Pathname]
    def file_path_report_json
      Noop::Config.dir_path_reports + file_name_report_json
    end

    # @return [Hash]
    def file_data_report_json
      return unless file_present_report_json?
      file_data = nil
      begin
        file_content = File.read file_path_report_json.to_s
        file_data = JSON.load file_content
        return unless file_data.is_a? Hash
      rescue
        nil
      end
      file_data
    end

    def file_remove_report_json
      file_path_report_json.unlink if file_present_report_json?
    end

    # @return [true,false]
    def file_present_report_json?
      file_path_report_json.exist?
    end

    def rspec_options
      options = '--color --tty'
      options += ' --format documentation' unless parallel_run?
      options
    end

    # @return [true,false]
    def rspec_command_run
      environment = {
          'SPEC_HIERA_NAME' => file_name_hiera.to_s,
          'SPEC_FACTS_NAME' => file_name_facts.to_s,
          'SPEC_FILE_NAME' => file_name_spec.to_s,
      }
      command = "rspec #{file_path_spec.to_s} #{rspec_options} --format json --out #{file_path_report_json.to_s}"
      command = "bundle exec #{command}" if ENV['SPEC_BUNDLE_EXEC']
      Dir.chdir Noop::Config.dir_path_root
      success = Noop::Utils.run environment, command
      set_status_value success
      success
    end

    attr_accessor :report
  end
end
