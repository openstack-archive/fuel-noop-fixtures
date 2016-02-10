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
      Noop::Utils.warning "#{self}: Validation is failed!" unless valid?
    end

    attr_accessor :parallel
    attr_accessor :pid
    attr_accessor :thread
    attr_accessor :status

    def success?
      status == :success
    end

    def failed?
      status == :failed
    end

    def pending?
      status == :pending
    end

    # @return [true,false]
    def parallel_run?
      parallel
    end

    # @return [true,false]
    def valid?
      unless file_path_spec.exist?
        Noop::Utils.warning "No spec file: #{file_path_spec}!"
        return false
      end
      unless file_path_manifest.exist?
        Noop::Utils.warning "No task file: #{file_path_manifest}!"
        return false
      end
      unless file_path_hiera.exist?
        Noop::Utils.warning "No hiera file: #{file_path_hiera}!"
        return false
      end
      unless file_path_facts.exist?
        Noop::Utils.error "No facts file: #{file_path_hiera}!"
        return false
      end
      true
    end

    # @return [String]
    def to_s
      "Task[#{file_base_spec}]"
    end

    def description
      message = ''
      message += "Task: #{file_name_manifest}"
      message += " Spec: #{file_name_spec}"
      message += " Hiera: #{file_name_hiera}"
      message += " Facts: #{file_name_facts}"
      message += " Status: #{status}"
      message
    end

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
