require 'pathname'

module Noop
  module Config
    # @return [Pathname]
    def self.dir_name_facts
      Pathname.new 'facts'
    end

    # @return [Pathname]
    def self.dir_path_facts
      return @dir_path_facts if @dir_path_facts
      @dir_path_facts = Noop::Utils.path_from_env 'SPEC_FACTS_DIR'
      @dir_path_facts = dir_path_root + dir_name_facts unless @dir_path_facts
      begin
        @dir_path_facts = @dir_path_facts.realpath
      rescue
        @dir_path_facts
      end
    end

    # @return [Pathname]
    def self.dir_name_facts_override
      Pathname.new 'override'
    end

    # @return [Pathname]
    def self.dir_path_facts_override
      dir_path_facts + dir_name_facts_override
    end

    def self.default_facts_file_name
      Pathname.new 'ubuntu16.yaml'
    end
  end
end
