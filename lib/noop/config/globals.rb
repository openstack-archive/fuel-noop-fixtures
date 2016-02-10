require 'pathname'

module Noop
  module Config
    # @return [Pathname]
    def self.spec_name_globals
      Pathname.new 'globals/globals_spec.rb'
    end

    # @return [Pathname]
    def self.spec_path_globals
      dir_path_task_spec + spec_name_globals
    end

    def self.manifest_name_globals
      Noop::Utils.convert_to_manifest spec_name_globals
    end

    def self.manifest_path_globals
      dir_path_tasks_local + manifest_name_globals
    end

    # @return [Pathname]
    def self.dir_name_globals
      Pathname.new 'globals'
    end

    # @return [Pathname]
    def self.dir_path_globals
      dir_path_hiera + dir_name_globals
    end
  end
end
