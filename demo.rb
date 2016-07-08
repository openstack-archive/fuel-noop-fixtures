#!/usr/bin/env ruby

require_relative './noop_tests'

ENV['SPEC_SPEC_DIR'] = './spec/demo-hosts'

if $0 == __FILE__
  manager = Noop::Manager.new
  manager.main
end
