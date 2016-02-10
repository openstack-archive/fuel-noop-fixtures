require 'yaml'

module Noop
  class Task
    # @return [Pathname]
    def file_name_facts
      return @file_name_facts if @file_name_facts
      self.file_name_facts = Noop::Utils.path_from_env 'SPEC_FACTS_NAME'
      return @file_name_facts if @file_name_facts
      self.file_name_facts = Noop::Config.default_facts_file_name
      @file_name_facts
    end
    alias :facts :file_name_facts

    # @return [Pathname]
    def file_name_facts=(value)
      return if value.nil?
      @file_name_facts = Noop::Utils.convert_to_path value
      @file_name_facts = @file_name_facts.sub_ext '.yaml' if @file_name_facts.extname == ''
    end
    alias :facts= :file_name_facts=

    # @return [Pathname]
    def file_base_facts
      file_name_facts.basename.sub_ext ''
    end

    # @return [Pathname]
    def file_path_facts
      Noop::Config.dir_path_facts + file_name_facts
    end

    # @return [true,false]
    def file_present_facts?
      return false unless file_path_facts
      file_path_facts.readable?
    end

    # @return [Pathname]
    def file_name_facts_override
      file_name_task_extension
    end

    # @return [Pathname]
    def file_path_facts_override
      Noop::Config.dir_path_facts_override + file_name_facts_override
    end

    # @return [true,false]
    def file_present_facts_override?
      return unless file_path_facts_override
      file_path_facts_override.readable?
    end

    # @return [Array<String>]
    def facts_hierarchy
      file_paths = []
      file_paths << file_path_facts.to_s if file_present_facts?
      file_paths << file_path_facts_override.to_s if file_present_facts_override?
      file_paths
    end

    def add_host_names(facts_data)
      hostname = hiera_lookup 'node_name'
      fqdn = hiera_lookup 'fqdn'
      facts_data[:hostname] = hostname if hostname
      facts_data[:l3_fqdn_hostname] = hostname if hostname
      facts_data[:fqdn] = fqdn if fqdn
    end

    # @return [Hash]
    def facts_data
      facts_data = {}
      facts_hierarchy.each do |file_path|
        begin
          file_data = YAML.load_file file_path
          next unless file_data.is_a? Hash
          facts_data.merge! file_data
        rescue
          next
        end
      end
      add_host_names facts_data
      facts_data
    end
    alias :ubuntu_facts :facts_data
    alias :centos_facts :facts_data

    def hostname
      facts_data[:hostname]
    end

    def fqdn
      facts_data[:fqdn]
    end

  end
end
