#!/usr/bin/env ruby

require_relative 'lib/noop/config'
require_relative 'lib/noop/task'
require_relative 'lib/noop/manager'
require_relative 'lib/noop/utils'

ENV['SPEC_SPEC_DIR'] = './spec/demo-hosts'

if $0 == __FILE__
  manager = Noop::Manager.new
  manager.main
end
