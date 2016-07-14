require 'pathname'

module Noop
  module Config
    # @return [Pathname]
    def self.dir_name_hiera
      Pathname.new 'hiera'
    end

    # @return [Pathname]
    def self.dir_path_hiera
      return @dir_path_hiera if @dir_path_hiera
      @dir_path_hiera = Noop::Utils.path_from_env 'SPEC_HIERA_DIR', 'SPEC_YAML_DIR'
      @dir_path_hiera = dir_path_root + dir_name_hiera unless @dir_path_hiera
      begin
        @dir_path_hiera = @dir_path_hiera.realpath
      rescue
        @dir_path_hiera
      end
    end

    # @return [Pathname]
    def self.dir_name_hiera_override
      Pathname.new 'override'
    end

    # @return [Pathname]
    def self.dir_path_hiera_override
      dir_path_hiera + dir_name_hiera_override
    end

    def self.default_hiera_file_name
      Pathname.new 'novanet-primary-controller.yaml'
    end

    # @return [Pathname]
    def self.file_name_hiera_plugins
      Pathname.new 'plugins'
    end

    # @return [Pathname]
    def self.file_path_hiera_plugins
      Noop::Config.dir_path_hiera + file_name_hiera_plugins
    end
  end
end
