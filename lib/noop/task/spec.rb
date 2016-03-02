module Noop
  class Task
    # @return [Pathname]
    def file_name_spec
      return @file_name_spec if @file_name_spec
      self.file_name_spec = Noop::Utils.path_from_env 'SPEC_FILE_NAME'
      error 'The spec file name is not set for this task!' unless file_name_spec_set?
      @file_name_spec
    end

    # Check if the spec name for this spec is set
    # @return [true,false]
    def file_name_spec_set?
      not @file_name_spec.nil?
    end

    # @return [Pathname]
    def file_base_spec
      Noop::Utils.convert_to_path(file_name_spec.to_s.gsub /_spec\.rb$/, '')
    end

    # @return [Pathname]
    def file_name_spec=(value)
      return if value.nil?
      @file_name_spec = Noop::Utils.convert_to_spec value
      @file_name_spec
    end

    # @return [Pathname]
    def file_name_manifest
      Noop::Utils.convert_to_manifest file_name_spec
    end

    # @return [Pathname]
    def file_path_manifest
      Noop::Config.dir_path_tasks_local + file_name_manifest
    end

    # @return [Pathname]
    def file_path_spec
      Noop::Config.dir_path_task_spec + file_name_spec
    end

    # @return [true,false]
    def file_present_spec?
      file_path_spec.readable?
    end

    # @return [true,false]
    def file_present_manifest?
      file_path_manifest.readable?
    end

    # @return [Pathname]
    def file_name_task_extension
      Noop::Utils.convert_to_path(file_base_spec.to_s.gsub('/', '-') + '.yaml')
    end

    # @return [Pathname]
    def file_name_base_task_report
      Noop::Utils.convert_to_path("#{file_name_task_extension.sub_ext ''}_#{file_base_hiera}_#{file_base_facts}")
    end

  end
end
