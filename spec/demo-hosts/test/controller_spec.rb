require 'spec_helper'
require 'shared-examples'

# ROLE: controller

manifest = 'test/controller.pp'

describe manifest, :type => :host do
  run_test manifest
end
