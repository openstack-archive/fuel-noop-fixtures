#!/usr/bin/env ruby

require_relative 'lib/noop/config'
require_relative 'lib/noop/task'
require_relative 'lib/noop/manager'
require_relative 'lib/noop/utils'

if $0 == __FILE__
  manager = Noop::Manager.new
  manager.main
end
