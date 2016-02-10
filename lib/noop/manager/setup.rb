module Noop
  class Manager
    PUPPET_GEM_VERSION = '~> 3.8.0'

    def dir_path_gem_home
      return Pathname.new ENV['GEM_HOME'] if ENV['GEM_HOME']
      dir_name_bundle = Pathname.new '.bundled_gems'
      Noop::Utils.dir_path_workspace + dir_name_bundle
    end

    def bundle_installed?
      `bundle --version`
      $?.exitstatus == 0
    end

    def setup_bundle
      Noop::Utils.error 'Bundle is not installed!' unless bundle_installed?
      ENV['GEM_HOME'] = dir_path_gem_home.to_s
      ENV['PUPPET_GEM_VERSION'] = PUPPET_GEM_VERSION unless ENV['PUPPET_GEM_VERSION']
      Dir.chdir Noop::Config.dir_path_root
      Noop::Utils.run 'bundle install'
      Noop::Utils.run 'bundle update'
      Noop::Utils.error 'Could not prepare bundle environment!' if $?.exitstatus != 0
    end

    # run librarian-puppet to fetch modules as necessary
    def prepare_library
      # these are needed to ensure we have the correctly bundle
      ENV['PUPPET_GEM_VERSION'] = PUPPET_GEM_VERSION unless ENV['PUPPET_GEM_VERSION']
      ENV['BUNDLE_DIR'] = dir_path_gem_home.to_s
      ENV['GEM_HOME'] = dir_path_gem_home.to_s
      command = './update_modules.sh -v'
      # pass the bundle parameter to update_modules if specified for this script
      command = command + ' -b' if options[:bundle_exec]
      # pass the reset parameter to update_modules if specified for this script
      command = command + ' -r' if options[:reset_librarian_puppet]

      Noop::Utils.debug 'Starting update_modules script'
      Dir.chdir Noop::Config.dir_path_deployment
      Noop::Utils.run command
      Noop::Utils.error 'Unable to update upstream puppet modules using librarian-puppet!' if $?.exitstatus != 0
      Noop::Utils.debug 'Finished update_modules script'
    end

  end
end
