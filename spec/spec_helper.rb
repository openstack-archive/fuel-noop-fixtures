require 'rubygems'
require 'puppet'
require 'hiera_puppet'
require 'rspec-puppet'
require 'rspec-puppet-utils'
require 'puppetlabs_spec_helper/module_spec_helper'

require_relative '../lib/noop'

# Add fixture lib dirs to LOAD_PATH. Work-around for PUP-3336
if Puppet.version < '4.0.0'
  Noop::Config.list_path_modules.each do |path|
    Dir["#{path}/*/lib"].entries.each do |lib_dir|
      $LOAD_PATH << lib_dir
    end
  end
end

RSpec.configure do |c|
  c.mock_with :rspec
  c.expose_current_running_example_as :example

  c.before :each do
    # avoid "Only root can execute commands as other users"
    Puppet.features.stubs(:root? => true)
    # clear cached facts
    Facter::Util::Loader.any_instance.stubs(:load_all)
    Facter.clear
    Facter.clear_messages
  end

end

Noop.setup_overrides
