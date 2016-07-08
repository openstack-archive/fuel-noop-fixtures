require 'spec_helper'
require 'shared-examples'

# ROLE: compute

manifest = 'test/compute.pp'

describe manifest, :type => :host do
  run_test manifest
end
