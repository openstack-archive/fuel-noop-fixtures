module Noop
  class Task

    # @return [Pathname]
    def file_path_globals
      Noop::Config.dir_path_globals + file_name_hiera
    end

    # @return [true,false]
    def file_present_globals?
      return false unless file_path_globals
      file_path_globals.readable?
    end

    def write_file_globals(content)
      debug "Saving Globals YAML file to: '#{file_path_globals.to_s}'"
      File.open(file_path_globals.to_s, 'w') do |file|
        file.write content
      end
    end

    # @return [Pathname]
    def file_name_globals
      file_name_hiera
    end

    # @return [Pathname]
    def file_base_globals
      file_base_hiera
    end

    # @return [Pathname]
    def element_globals
      Noop::Config.dir_name_globals + file_base_globals
    end
  end
end
