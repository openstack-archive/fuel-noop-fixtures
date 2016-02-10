#!/usr/bin/env ruby

require_relative 'lib/noop/config'
require_relative 'lib/noop/task'
require_relative 'lib/noop/manager'
require_relative 'lib/noop/utils'

manager = Noop::Manager.new
manager.main
