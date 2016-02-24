module Noop
  class Task
    def initialize(spec=nil, hiera=nil, facts=nil)
      self.status = :pending
      self.file_name_spec = Noop::Utils.convert_to_spec spec if spec
      self.file_name_hiera = hiera if hiera
      self.file_name_facts = facts if facts
      self.pid = Process.pid
      self.thread = Thread.current.object_id
      @parallel = false
    end

    attr_accessor :parallel
    attr_accessor :pid
    attr_accessor :thread
    attr_accessor :status
    attr_accessor :valid

    # Check if this task's configuration is valid
    # @return [true,false]
    def valid?
      validate unless valid.is_a? TrueClass or valid.is_a? FalseClass
      valid
    end

    # @return [true,false]
    def success?
      status == :success
    end

    # @return [true,false]
    def failed?
      status == :failed
    end

    # @return [true,false]
    def pending?
      status == :pending
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

    # Write an error message to the log
    # and raise the exception
    # @return [void]
    def error(message)
      Noop::Utils.error message
    end

    # Write a warning message to the log
    # @return [void]
    def warning(message)
      Noop::Utils.warning message
    end

    # @return [true,false]
    def parallel_run?
      parallel
    end

    # @return [true,false]
    def validate
      if file_name_spec_set?
        unless file_present_spec?
          warning "No spec file: #{file_path_spec}!"
          self.valid = false
          return valid
        end
      else
        warning 'Spec file is not set for this task!'
        self.valid = false
        return valid
      end

      unless file_present_manifest?
        warning "No task file: #{file_path_manifest}!"
        self.valid = false
        return valid
      end
      unless file_present_hiera?
        warning "No hiera file: #{file_path_hiera}!"
        self.valid = false
        return valid
      end
      unless file_present_facts?
        warning "No facts file: #{file_path_hiera}!"
        self.valid = false
        return valid
      end
      self.valid = true
    end

    # @return [String]
    def to_s
      "Task[#{file_base_spec}]"
    end

    # @return [String]
    def description
      message = ''
      message += "Manifest: #{file_name_manifest}"
      message += " Spec: #{file_name_spec}"
      message += " Hiera: #{file_name_hiera}"
      message += " Facts: #{file_name_facts}"
      message += " Status: #{status}"
      message
    end

    # @return [String]
    def process_info
      message = ''
      message + "Object: #{object_id}"
      message += " Pid: #{pid}" if pid
      message += " Thread: #{thread}" if thread
      message
    end

    # @return [Strong]
    def inspect
      "Task[#{description}]"
    end

  end
end
