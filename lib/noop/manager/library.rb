require 'yaml'
require 'set'

module Noop
  class Manager

    # Recursively find file in the folder
    # @param root [String,Pathname]
    # @param exclude [Array<Pathname>]
    # @return [Array<Pathname>]
    def find_files(root, path_from=nil, exclude=[], &block)
      exclude = [exclude] unless exclude.is_a? Array
      root = Noop::Utils.convert_to_path root
      files = []
      begin
        root.children.each do |path|
          next if exclude.include? path.basename
          if path.file?
            if block_given?
              next unless block.call path
            end
            path = path.relative_path_from path_from if path_from
            files << path
          else
            files << find_files(path, path_from, exclude, &block)
          end
        end
      rescue
        []
      end
      files.flatten
    end

    # Scan the spec directory and gather the list of spec files
    # @return [Array<Pathname>]
    def spec_file_names
      return @spec_file_names if @spec_file_names
      error "No #{Noop::Config.dir_path_task_spec} directory!" unless Noop::Config.dir_path_task_spec.directory?
      @spec_file_names = find_files(Noop::Config.dir_path_task_spec, Noop::Config.dir_path_task_spec) do |file|
        file.to_s.end_with? '_spec.rb'
      end
    end

    # Scan the Hiera directory and gather the list of Hiera files
    # @return [Array<Pathname>]
    def hiera_file_names
      return @hiera_file_names if @hiera_file_names
      error "No #{Noop::Config.dir_path_hiera} directory!" unless Noop::Config.dir_path_hiera.directory?
      exclude = [ Noop::Config.dir_name_hiera_override, Noop::Config.dir_name_globals ]
      @hiera_file_names = find_files(Noop::Config.dir_path_hiera, Noop::Config.dir_path_hiera, exclude) do |file|
        file.to_s.end_with? '.yaml'
      end
    end

    # Scan the facts directory and gather the list of facts files
    # @return [Array<Pathname>]
    def facts_file_names
      return @facts_file_names if @facts_file_names
      error "No #{Noop::Config.dir_path_facts} directory!" unless Noop::Config.dir_path_facts.directory?
      exclude = [ Noop::Config.dir_name_facts_override ]
      @facts_file_names = find_files(Noop::Config.dir_path_facts, Noop::Config.dir_path_facts, exclude) do |file|
        file.to_s.end_with? '.yaml'
      end
    end

    # Scan the tasks directory and gather the list of task files
    # @return [Array<Pathname>]
    def task_file_names
      return @task_file_names if @task_file_names
      error "No #{Noop::Config.dir_path_tasks_local} directory!" unless Noop::Config.dir_path_tasks_local.directory?
      @task_file_names = find_files(Noop::Config.dir_path_tasks_local, Noop::Config.dir_path_tasks_local) do |file|
        file.to_s.end_with? '.pp'
      end
    end

    # Read the task deployment graph metadata files in the library:
    # Find all 'tasks.yaml' files in the puppet directory.
    # Read them all to a Hash by their ids.
    # Find all 'groups' records and resolve their 'tasks' reference
    # by pointing referenced tasks to this group instead.
    # @return [Hash<String => Hash>]
    def task_graph_metadata
      return @task_graph_metadata if @task_graph_metadata
      @task_graph_metadata = {}
      error "No #{Noop::Config.dir_path_modules_local} directory!" unless Noop::Config.dir_path_modules_local.directory?
      Noop::Config.dir_path_modules_local.find do |task_file|
        next unless task_file.file?
        next unless task_file.to_s.end_with? 'tasks.yaml'
        begin
          tasks = YAML.load_file task_file
        rescue
          next
        end
        tasks.each do |task|
          id = task['id']
          @task_graph_metadata[id] = task
        end
      end

      @task_graph_metadata.each do |id, group_task|
        next unless group_task['type'] == 'group' and group_task['tasks'].is_a? Array
        group_task['tasks'].each do |task|
          next unless @task_graph_metadata[task]
          @task_graph_metadata[task]['groups'] = [] unless @task_graph_metadata[task]['groups'].is_a? Array
          @task_graph_metadata[task]['groups'] << id
        end
      end

      @task_graph_metadata
    end

    # Try to determine the roles each spec should be run in using
    # the deployment graph metadata. Take a list of groups or roles
    # and form a set of them.
    # @return [Hash<Pathname => Set>]
    def assign_spec_to_roles
      return @assign_spec_to_roles if @assign_spec_to_roles
      @assign_spec_to_roles = {}
      task_graph_metadata.values.each do |task_data|
        roles = (task_data['groups'] or task_data['roles'] or task_data['role'])
        next unless roles
        roles = [roles] unless roles.is_a? Array
        file_path_manifest = task_data.fetch('parameters', {}).fetch('puppet_manifest', nil)
        next unless file_path_manifest
        file_path_manifest = Pathname.new file_path_manifest
        file_name_manifest = file_path_manifest.relative_path_from Noop::Config.dir_path_tasks_node
        file_name_spec = Noop::Utils.convert_to_spec file_name_manifest
        roles = Set.new roles
        @assign_spec_to_roles[file_name_spec] = Set.new unless @assign_spec_to_roles[file_name_spec].is_a? Set
        @assign_spec_to_roles[file_name_spec] += roles
      end
      @assign_spec_to_roles
    end

    # Try to determine the roles of each Hiera file.
    # Take 'nodes' structure and find 'node_roles' of the current node their.
    # Form a set of found values and add root 'role' value if found.
    # @return [Hash<Pathname => Set>]
    def assign_hiera_to_roles
      return @assign_hiera_to_roles if @assign_hiera_to_roles
      @assign_hiera_to_roles = {}
      hiera_file_names.each do |hiera_file|
        begin
          data = YAML.load_file(Noop::Config.dir_path_hiera + hiera_file)
          next unless data.is_a? Hash
          fqdn = data['fqdn']
          next unless fqdn
          nodes = data.fetch('network_metadata', {}).fetch('nodes', nil)
          next unless nodes
          this_node = nodes.find do |node|
            node.last['fqdn'] == fqdn
          end
          node_roles = this_node.last['node_roles']
          roles = Set.new
          roles.merge node_roles if node_roles.is_a? Array
          role = data['role']
          roles.add role if role
          @assign_hiera_to_roles[hiera_file] = roles
        rescue
          next
        end
      end
      @assign_hiera_to_roles
    end

    # Determine Hiera files for each spec file by calculating
    # the intersection between their roles sets.
    # If the spec file contains '*' role it should be counted
    # as all possible roles.
    # @return [Hash<Pathname => Pathname]
    def assign_spec_to_hiera
      return @assign_spec_to_hiera if @assign_spec_to_hiera
      @assign_spec_to_hiera = {}
      assign_spec_to_roles.each do |file_name_spec, spec_roles_set|
        hiera_files = get_hiera_for_roles spec_roles_set
        @assign_spec_to_hiera[file_name_spec] = hiera_files if hiera_files.any?
      end
      @assign_spec_to_hiera
    end

    # Read all spec annotations metadata.
    # @return [Hash<Pathname => Array>]
    def spec_run_metadata
      return @spec_run_metadata if @spec_run_metadata
      @spec_run_metadata = {}
      Noop::Config.dir_path_task_spec.find do |spec_file|
        next unless spec_file.file?
        next unless spec_file.to_s.end_with? '_spec.rb'
        spec_name = spec_file.relative_path_from(Noop::Config.dir_path_task_spec)
        spec_data = parse_spec_file spec_file
        @spec_run_metadata[spec_name] = spec_data if spec_data.any?
      end
      @spec_run_metadata
    end

    # Parse a spec file to find annotation entries.
    # @param [Pathname] task_spec
    # @return [Hash]
    def parse_spec_file(task_spec)
      task_spec_metadata = {}

      begin
        text = task_spec.read
        text.split("\n").each do |line|
          line = line.downcase

          if line =~ /^\s*#\s*(?:yamls|hiera):\s*(.*)/
            task_spec_metadata[:hiera] = [] unless task_spec_metadata[:hiera].is_a? Array
            task_spec_metadata[:hiera] += get_list_of_yamls $1
          end

          if line =~ /^\s*#\s*facts:\s*(.*)/
            task_spec_metadata[:facts] = [] unless task_spec_metadata[:facts].is_a? Array
            task_spec_metadata[:facts] += get_list_of_yamls $1
          end

          if line =~ /^\s*#\s*(?:skip_yamls|skip_hiera):\s(.*)/
            task_spec_metadata[:skip_hiera] = [] unless task_spec_metadata[:skip_hiera].is_a? Array
            task_spec_metadata[:skip_hiera] += get_list_of_yamls $1
          end

          if line =~ /^\s*#\s*skip_facts:\s(.*)/
            task_spec_metadata[:skip_facts] = [] unless task_spec_metadata[:skip_facts].is_a? Array
            task_spec_metadata[:skip_facts] += get_list_of_yamls $1
          end

          if line =~ /^\s*#\s*disable_spec/
            task_spec_metadata[:disable] = true
          end

          if line =~ /^\s*#\s*role:\s*(.*)/
            task_spec_metadata[:roles] = [] unless task_spec_metadata[:roles].is_a? Array
            roles = line.split /\s*,\s*|\s+/
            task_spec_metadata[:roles] += roles
          end

          if line =~ /^\s*#\s*run:\s*(.*)/
            run_record = get_list_of_yamls $1
            if run_record.length >= 2
              run_record = {
                  :hiera => run_record[0],
                  :facts => run_record[1],
              }
              task_spec_metadata[:runs] = [] unless task_spec_metadata[:runs].is_a? Array
              task_spec_metadata[:runs] << run_record
            end
          end
        end
      rescue
        return task_spec_metadata
      end
      task_spec_metadata
    end

    # Split a space or comma separated list of yaml files
    # and form an Array of the yaml file names.
    # @return [Array<Pathname>]
    def get_list_of_yamls(line)
      line = line.split /\s*,\s*|\s+/
      line.map do |yaml|
        yaml = Pathname.new yaml
        yaml = yaml.sub /$/, '.yaml' unless yaml.extname =~ /\.yaml/i
        yaml
      end
    end

    # Determine the list of run records for a spec file:
    # Take a list of explicitly defined runs if present.
    # Make product of allowed Hiera and facts yaml files to
    # form more run records.
    # Use the default facts file name if there is none
    # is given in the annotation.
    # Use the list of Hiera files determined by the intersection of
    # deployment graph metadata and Hiera yaml contents using roles
    # as a common data.
    def get_spec_runs(file_name_spec)
      file_name_spec = Noop::Utils.convert_to_path file_name_spec
      metadata = spec_run_metadata.fetch file_name_spec, {}
      metadata[:facts] = [Noop::Config.default_facts_file_name] unless metadata[:facts]

      if metadata[:roles]
        metadata[:hiera] = [] unless metadata[:hiera]
        metadata[:hiera] += get_hiera_for_roles metadata[:roles]
      end

      # the last default way to get hiera files list
      metadata[:hiera] = assign_spec_to_hiera.fetch file_name_spec, [] unless metadata[:hiera]

      runs = []
      metadata[:facts].product metadata[:hiera] do |facts, hiera|
        next if metadata[:skip_hiera].is_a? Array and metadata[:skip_hiera].include? hiera
        next if metadata[:skip_facts].is_a? Array and metadata[:skip_facts].include? hiera
        run_record = {
            :hiera => hiera,
            :facts => facts,
        }
        runs << run_record
      end
      runs += metadata[:runs] if metadata[:runs].is_a? Array
      runs
    end

    # Get a list of Hiera YAML files which roles
    # include the given set of roles
    # @param roles [Array,Set,String]
    # @return [Array]
    def get_hiera_for_roles(*roles)
      all_roles = Set.new
      roles.flatten.each do |role|
        if role.is_a? Set
          all_roles += role
        else
          all_roles.add role
        end
      end
      if all_roles.include? '*'
        assign_hiera_to_roles.keys
      else
        assign_hiera_to_roles.select do |_file_name_hiera, hiera_roles_set|
          roles_intersection = hiera_roles_set & all_roles
          roles_intersection.any?
        end.keys
      end
    end

    # Check if the given element matches this filter
    # @param [Array<String>]
    def filter_is_matched?(filter, element)
      return true unless filter
      filter = [filter] unless filter.is_a? Array
      filter.any? do |expression|
        expression = Regexp.new expression.to_s
        expression =~ element.to_s
      end
    end

    # Use filters to check if this spec file is included
    # @return [true,false]
    def spec_included?(spec)
      filter_is_matched? options[:filter_specs], spec
    end

    # Use filters to check if this facts file is included
    # @return [true,false]
    def facts_included?(facts)
      filter_is_matched? options[:filter_facts], facts
    end

    # Use filters to check if this Hiera file is included
    # @return [true,false]
    def hiera_included?(hiera)
      filter_is_matched? options[:filter_hiera], hiera
    end

    # Check if the globals spec should be skipped.
    # It should not be skipped only if it's explicitly enabled in the filter.
    # @return [true,false]
    def skip_globals?(file_name_spec)
      return false unless file_name_spec == Noop::Config.spec_name_globals
      return true unless options[:filter_specs]
      not spec_included? file_name_spec
    end

    # Check if the spec is disabled using the annotation
    # @return [true,false]
    def spec_is_disabled?(file_name_spec)
      file_name_spec = Noop::Utils.convert_to_path file_name_spec
      spec_run_metadata.fetch(file_name_spec, {}).fetch(:disable, false)
    end

    # Form the final list of Task objects that should be running.
    # Take all discovered spec files, get run records for them,
    # apply filters to exclude filtered records.
    # @return [Array<Noop::Task>]
    def task_list
      return @task_list if @task_list
      @task_list = []
      spec_file_names.each do |file_name_spec|
        next if spec_is_disabled? file_name_spec
        next if skip_globals? file_name_spec
        next unless spec_included? file_name_spec
        get_spec_runs(file_name_spec).each do |run|
          next unless run[:hiera] and run[:facts]
          next unless facts_included? run[:facts]
          next unless hiera_included? run[:hiera]
          task = Noop::Task.new file_name_spec, run[:hiera], run[:facts]
          task.parallel = true if parallel_run?
          @task_list << task
        end
      end
      @task_list
    end

    # Loop through all task files and find those that
    # do not have a corresponding spec file present
    # @return [Array<Pathname>]
    def find_tasks_without_specs
      task_file_names.reject do |manifest|
        spec = Noop::Utils.convert_to_spec manifest
        spec_file_names.include? spec
      end
    end

    # Loop through all spec files and find those that
    # do not have a corresponding task file present
    # @return [Array<Pathname>]
    def find_specs_without_tasks
      spec_file_names.reject do |spec|
        manifest = Noop::Utils.convert_to_manifest spec
        task_file_names.include? manifest
      end
    end

    # Loop through all spec files and find those
    # which have not been matched to any task
    # @return [Array<Pathname>]
    def find_unmatched_specs
      spec_file_names.reject do |spec|
        next true if spec == Noop::Config.spec_name_globals
        task_list.any? do |task|
          task.file_name_spec == spec
        end
      end
    end

  end
end
