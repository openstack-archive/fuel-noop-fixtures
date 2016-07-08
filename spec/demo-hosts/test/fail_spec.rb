require 'spec_helper'
require 'shared-examples'

# HIERA: master

manifest = 'test/fail.pp'

describe manifest, :type => :host do
  run_test manifest
end
