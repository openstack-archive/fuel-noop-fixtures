require 'json'

module Noop
  class Task
    # Run the actual spec of this task.
    # It will execute the rspec command and will manage report files.
    def run
      validate
      error 'Validation of this task have failed!' unless valid?
      return unless pending?
      self.pid = Process.pid
      self.thread = Thread.current.object_id
      debug "RUN: #{self.inspect}"
      file_remove_report_json
      rspec_command_run
      file_load_report_json
      determine_task_status
      debug "FINISH: #{self.inspect}"
      status
    end

    # Set the status string of the task according to run results
    def set_status_value(value)
      if value.is_a? TrueClass
        self.status = :success
      elsif value.is_a? FalseClass
        self.status = :failed
      else
        self.status = :pending
      end
    end

    # Try to determine the task status based on the report data
    def determine_task_status
      if report.is_a? Hash
        failures = report.fetch('summary', {}).fetch('failure_count', nil)
        if failures.is_a? Numeric
          set_status_value(failures == 0)
        end
      end
      status
    end

    # Additional RSpec options
    def rspec_options
      options = '--color --tty'
      options += ' --format documentation' unless parallel_run?
      options
    end

    # Run the RSpec command and pass Hiera, facts and spec files names
    # using the environment variables.
    # Use bundler if it's enabled.
    # Set the task status according to the RSpec exit code.
    # @return [true,false]
    def rspec_command_run
      environment = {
          'SPEC_HIERA_NAME' => file_name_hiera.to_s,
          'SPEC_FACTS_NAME' => file_name_facts.to_s,
          'SPEC_FILE_NAME' => file_name_spec.to_s,
          'GEM_HOME' => Noop::Config.dir_path_gem_home.to_s,
      }
      command = "rspec #{file_path_spec.to_s} #{rspec_options} --format json --out #{file_path_report_json.to_s}"
      command = "bundle exec #{command}" if ENV['SPEC_BUNDLE_EXEC']
      Dir.chdir Noop::Config.dir_path_root
      success = Noop::Utils.run environment, command
      if success.nil?
        debug 'RSpec command is not found!'
        success = false
      end
      set_status_value success
      success
    end

  end
end
