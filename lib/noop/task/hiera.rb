module Noop
  class Task
    # @return [Pathname]
    def file_name_hiera
      return @file_name_hiera if @file_name_hiera
      self.file_name_hiera = Noop::Utils.path_from_env 'SPEC_ASTUTE_FILE_NAME', 'SPEC_HIERA_NAME'
      return @file_name_hiera if @file_name_hiera
      self.file_name_hiera = Noop::Config.default_hiera_file_name unless
      @file_name_hiera
    end

    # @return [Pathname]
    def file_name_hiera=(value)
      return if value.nil?
      @file_name_hiera = Noop::Utils.convert_to_path value
      @file_name_hiera = @file_name_hiera.sub_ext '.yaml' if @file_name_hiera.extname == ''
    end

    # @return [Pathname]
    def file_base_hiera
      file_name_hiera.basename.sub_ext ''
    end

    # @return [Pathname]
    def file_path_hiera
      Noop::Config.dir_path_hiera + file_name_hiera
    end

    # @return [true,false]
    def file_present_hiera?
      return false unless file_path_hiera
      file_path_hiera.readable?
    end

    # @return [Pathname]
    def element_hiera
      file_base_hiera
    end

    # @return [Pathname]
    def file_name_hiera_override
      file_name_task_extension
    end

    # @return [Pathname]
    def file_path_hiera_override
      Noop::Config.dir_path_hiera_override + file_name_hiera_override
    end

    # @return [true,false]
    def file_present_hiera_override?
      return unless file_path_hiera_override
      file_path_hiera_override.readable?
    end

    # @return [Pathname]
    def element_hiera_override
      override_file = file_name_hiera_override
      return unless override_file
      Noop::Config.dir_name_hiera_override + override_file.sub_ext('')
    end

    # @return [Pathname]
    def dir_path_task_hiera_plugins
      Noop::Config.file_path_hiera_plugins + file_base_hiera
    end

    # @return [Array<Pathname>]
    def list_hiera_plugins
      return @list_hiera_plugins if @list_hiera_plugins
      @list_hiera_plugins = [] unless @list_hiera_plugins
      return @list_hiera_plugins unless dir_path_task_hiera_plugins.directory?
      dir_path_task_hiera_plugins.children.each do |file|
        next unless file.file?
        next unless file.to_s.end_with? '.yaml'
        file = file.relative_path_from Noop::Config.dir_path_hiera
        file = file.sub_ext('')
        @list_hiera_plugins << file
      end
      @list_hiera_plugins.sort!
      @list_hiera_plugins
    end

    # @return [String]
    def hiera_logger
      if ENV['SPEC_PUPPET_DEBUG']
        'console'
      else
        'noop'
      end
    end

    # @return [Array<String>]
    def hiera_hierarchy
      elements = []
      elements += list_hiera_plugins.map(&:to_s) if list_hiera_plugins.any?
      elements << element_hiera_override.to_s if file_present_hiera_override?
      elements << element_globals.to_s if file_present_globals?
      elements << element_hiera.to_s if file_present_hiera?
      elements
    end

    # @return [Hash]
    def hiera_config
      {
          :backends => [
              'yaml',
          ],
          :yaml => {
              :datadir => Noop::Config.dir_path_hiera.to_s,
          },
          :hierarchy => hiera_hierarchy,
          :logger => hiera_logger,
          :merge_behavior => :deeper,
      }
    end

    # @return [Hiera]
    def hiera_object
      return @hiera_object if @hiera_object
      @hiera_object = Hiera.new(:config => hiera_config)
      Hiera.logger = hiera_config[:logger]
      @hiera_object
    end

    # @return [Object]
    def hiera_lookup(key, default = nil, resolution_type = :priority)
      key = key.to_s
      # def lookup(key, default, scope, order_override=nil, resolution_type=:priority)
      hiera_object.lookup key, default, {}, nil, resolution_type
    end
    alias :hiera :hiera_lookup

    # @return [Hash]
    def hiera_hash(key, default = nil)
      hiera_lookup key, default, :hash
    end

    # @return [Array]
    def hiera_array(key, default = nil)
      hiera_lookup key, default, :array
    end

    # @return [Object]
    def hiera_structure(key, default = nil, separator = '/', resolution_type = :hash)
      path_lookup = lambda do |data, path, default_value|
        break default_value unless data
        break data unless path.is_a? Array and path.any?
        break default_value unless data.is_a? Hash or data.is_a? Array

        key = path.shift
        if data.is_a? Array
          begin
            key = Integer key
          rescue ArgumentError
            break default_value
          end
        end
        path_lookup.call data[key], path, default_value
      end

      path = key.split separator
      key = path.shift
      data = hiera key, nil, resolution_type
      path_lookup.call data, path, default
    end
    alias :hiera_dir :hiera_structure

  end
end
