require 'pathname'

module Noop
  module Config
    # @return [Pathname]
    def self.dir_path_config
      return @dirname if @dirname
      @dirname = Pathname.new(__FILE__).dirname.realpath
    end

    # @return [Pathname]
    def self.dir_path_root
      return @dir_path_root if @dir_path_root
      @dir_path_root = Noop::Utils.path_from_env 'SPEC_ROOT_DIR'
      @dir_path_root = dir_path_config.parent.parent.parent unless @dir_path_root
      begin
        @dir_path_root = @dir_path_root.realpath
      rescue
        @dir_path_root
      end
    end

    # @return [Pathname]
    def self.dir_path_task_spec
      return @dir_path_task_spec if @dir_path_task_spec
      @dir_path_task_spec = Noop::Utils.path_from_env 'SPEC_SPEC_DIR'
      @dir_path_task_spec = dir_path_root + 'spec' + 'hosts' unless @dir_path_task_spec
      begin
        @dir_path_task_spec = @dir_path_task_spec.realpath
      rescue
        @dir_path_task_spec
      end
    end

    # @return [Pathname]
    def self.dir_path_modules_local
      return @dir_path_modules_local if @dir_path_modules_local
      @dir_path_modules_local = Noop::Utils.path_from_env 'SPEC_MODULEPATH', 'SPEC_MODULE_PATH'
      @dir_path_modules_local = dir_path_root + 'modules' unless @dir_path_modules_local
      begin
        @dir_path_modules_local = @dir_path_modules_local.realpath
      rescue
        @dir_path_modules_local
      end
    end

    # @return [Pathname]
    def self.dir_path_tasks_local
      return @dir_path_tasks_local if @dir_path_tasks_local
      @dir_path_tasks_local = Noop::Utils.path_from_env 'SPEC_TASK_DIR'
      @dir_path_tasks_local = dir_path_root + 'tasks' unless @dir_path_tasks_local
      begin
        @dir_path_tasks_local = @dir_path_tasks_local.realpath
      rescue
        @dir_path_tasks_local
      end
    end

    # @return [Pathname]
    def self.dir_path_modules_node
      return @dir_path_modules_node if @dir_path_modules_node
      @dir_path_modules_node = Pathname.new '/etc/puppet/modules'
    end

    # @return [Pathname]
    def self.dir_path_tasks_node
      return @dir_path_tasks_node if @dir_path_tasks_node
      @dir_path_tasks_node = dir_path_modules_node + 'osnailyfacter' + 'modular'
    end

    # @return [Pathname]
    def self.dir_path_deployment
      return @dir_path_deployment if @dir_path_deployment
      @dir_path_deployment = Noop::Utils.path_from_env 'SPEC_DEPLOYMENT_DIR'
      @dir_path_deployment = dir_path_root + 'deployment' unless @dir_path_deployment
      begin
        @dir_path_deployment = @dir_path_deployment.realpath
      rescue
        @dir_path_deployment
      end
    end

    # Workspace directory where gem bundle will be created
    # is passed from Jenkins or the default value is used
    # @return [Pathname]
    def self.dir_path_workspace
      return @dir_path_workspace if @dir_path_workspace
      @dir_path_workspace = Noop::Utils.path_from_env 'WORKSPACE'
      @dir_path_workspace = Noop::Config.dir_path_root + Pathname.new('workspace') unless @dir_path_workspace
      begin
        @dir_path_workspace = @dir_path_workspace.realpath
      rescue
        nil
      end
      @dir_path_workspace.mkpath
      raise "Workspace '#{@dir_path_workspace}' is not a directory!" unless @dir_path_workspace.directory?
      @dir_path_workspace
    end

    # The name of the gem home directory
    # @return [Pathname]
    def self.dir_name_gem_home
      Pathname.new 'bundled_gems'
    end

    # Get a GEM_HOME either from the environment (using RVM)
    # or from the default value (using bundle)
    # @return [Pathname]
    def self.dir_path_gem_home
      return @dir_path_gem_home if @dir_path_gem_home
      @dir_path_gem_home = Noop::Utils.path_from_env 'GEM_HOME'
      return @dir_path_gem_home if @dir_path_gem_home
      @dir_path_gem_home = dir_path_workspace + dir_name_gem_home
      @dir_path_gem_home
    end

    # @return [Pathname]
    def self.dir_path_reports
      return @dir_path_reports if @dir_path_reports
      @dir_path_reports = dir_path_root + 'reports'
    end
  end
end
