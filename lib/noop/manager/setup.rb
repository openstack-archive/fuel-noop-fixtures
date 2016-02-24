module Noop
  class Manager

    # Get a GEM_HOME either from the environment (using RVM)
    # or from the default value (using bundle)
    # @return [Pathname]
    def dir_path_gem_home
      return Pathname.new ENV['GEM_HOME'] if ENV['GEM_HOME']
      dir_name_bundle = Pathname.new 'bundled_gems'
      Noop::Config.dir_path_workspace + dir_name_bundle
    end

    # Check if bundle command is installed
    # @return [true,false]
    def bundle_installed?
      `bundle --version`
      $?.exitstatus == 0
    end

    # Check if librarian-puppet command is installed
    # @return [true,false]
    def librarian_installed?
      `librarian-puppet version`
      $?.exitstatus == 0
    end

    # Setup bundle in the fixtures repo and bundle for puppet librarian
    def setup_bundle
      ENV['GEM_HOME'] = dir_path_gem_home.to_s
      bundle_install_and_update Noop::Config.dir_path_root
      bundle_install_and_update Noop::Config.dir_path_deployment
      Dir.chdir Noop::Config.dir_path_root
    end

    # Run update script to setup external Puppet modules
    def setup_library
      ENV['GEM_HOME'] = dir_path_gem_home.to_s
      update_puppet_modules Noop::Config.dir_path_deployment
      Dir.chdir Noop::Config.dir_path_root
    end

    # @return [Pathname]
    def file_name_gemfile_lock
      Pathname.new 'Gemfile.lock'
    end

    # Remove the Gem lock file at the given path
    # @param root [String,Pathname]
    def remove_gemfile_lock(root)
      root = Noop::Utils.convert_to_path root
      lock_file_path = root + file_name_gemfile_lock
      if  lock_file_path.file?
        debug "Removing Gem lock file: '#{lock_file_path}'"
        lock_file_path.unlink
      end
    end

    # Run bundles install and update actions in the given folder
    # @param root [String,Pathname]
    def bundle_install_and_update(root)
      error 'Bundle is not installed!' unless bundle_installed?
      root = Noop::Utils.convert_to_path root
      remove_gemfile_lock root
      Dir.chdir root or error "Could not chdir to: #{root}"
      debug "Starting 'bundle install' at: '#{root}' with the Gem home: '#{ENV['GEM_HOME']}'"
      Noop::Utils.run 'bundle install'
      error 'Could not prepare bundle environment!' if $?.exitstatus != 0
      debug "Starting 'bundle update' at: '#{root}' with the Gem home: '#{ENV['GEM_HOME']}'"
      Noop::Utils.run 'bundle update'
      error 'Could not update bundle environment!' if $?.exitstatus != 0
    end

    # Run librarian-puppet to fetch modules as
    # necessary modules at the given folder
    # @param root [String,Pathname]
    def update_puppet_modules(root)
      error 'Puppet Librarian is not installed!' unless librarian_installed?
      root = Noop::Utils.convert_to_path root
      Dir.chdir root or error "Could not chdir to: #{root}"
      command = './update_modules.sh -v'
      command = command + ' -b' if options[:bundle_exec]
      command = command + ' -r' if options[:reset_librarian_puppet]

      debug 'Starting update_modules script'
      Noop::Utils.run command
      error 'Unable to update upstream puppet modules using librarian-puppet!' if $?.exitstatus != 0
      debug 'Finished update_modules script'
    end

  end
end
