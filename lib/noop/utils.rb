module Noop
  module Utils
    # @param [Array<String>, String] names
    # @return [Pathname, nil]
    def self.path_from_env(*names)
      names.each do |name|
        name = name.to_s
        return convert_to_path ENV[name] if ENV[name]
      end
      nil
    end

    # @param [Object] value
    # @return [Pathname]
    def self.convert_to_path(value)
      value = Pathname.new value.to_s unless value.is_a? Pathname
      value
    end

    def self.convert_to_manifest(spec)
      manifest = spec.to_s.gsub /_spec\.rb$/, '.pp'
      convert_to_path manifest
    end

    def self.convert_to_spec(value)
      value = value.to_s.chomp.strip
      value = value[0...-3] if value.end_with? '.pp'
      value += '_spec.rb' unless value.end_with? '_spec.rb'
      convert_to_path value
    end

    def self.convert_to_yaml(value)
      value = value.to_s.chomp.strip
      value = convert_to_path value
      value = value.sub /$/, '.yaml' unless value.extname =~ /\.yaml/i
      value
    end

    # Run the code block inside the tests directory
    # and then return back
    def self.inside_task_root_dir
      current_directory = Dir.pwd
      Dir.chdir Noop::Config.dir_path_root
      result = yield
      Dir.chdir current_directory if current_directory
      result
    end

    # Run the code block inside the deployment directory
    # and then return back
    def self.inside_deployment_directory
      current_directory = Dir.pwd
      Dir.chdir Noop::Config.dir_path_deployment
      result = yield
      Dir.chdir current_directory if current_directory
      result
    end

    def self.run(*args)
      # debug "CMD: #{args.inspect} PWD: #{Dir.pwd}"
      system *args
    end

    def self.debug(message)
      Noop::Config.log.debug message
    end

    def self.info(message)
      Noop::Config.log.info message
    end

    def self.warning(message)
      Noop::Config.log.warn message
    end

    def self.error(message)
      Noop::Config.log.fatal message
      fail message
    end

    def self.output(message)
      puts message
    end

    def self.separator(title=nil)
      if title
        "=< #{title} >=".ljust 70, '='
      else
        '=' * 70
      end
    end
  end
end
