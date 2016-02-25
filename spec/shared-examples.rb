require_relative 'hosts/common.rb'

shared_examples 'compile' do
  it { is_expected.to compile }
end

shared_examples 'show_catalog' do
  it 'shows catalog contents' do
    puts '=' * 80
    puts Noop.task.catalog_dump self
    puts '=' * 80
  end
end

shared_examples 'status' do
  it 'shows status' do
    puts '=' * 80
    puts Noop.task.status_report self
    puts '=' * 80
  end
end

shared_examples 'console' do
  it 'runs pry console' do
    require 'pry'
    binding.pry
  end
end

###############################################################################

def run_test(manifest_file, *args)
  Noop.task_spec = manifest_file unless Noop.task_spec

  Noop::Config.log.progname = 'noop_spec'
  Noop::Utils.debug "RSPEC: #{Noop.task.inspect}"

  include FuelRelationshipGraphMatchers

  let(:task) do
    Noop.task
  end

  before(:all) do
    Noop.setup_overrides
  end

  let(:facts) do
    Noop.facts_data
  end

  let (:catalog) do
    catalog = subject
    catalog = catalog.call if catalog.is_a? Proc
  end

  let (:ral) do
    ral = catalog.to_ral
    ral.finalize
    ral
  end

  let (:graph) do
    graph = Puppet::Graph::RelationshipGraph.new(Puppet::Graph::TitleHashPrioritizer.new)
    graph.populate_from(ral)
    graph
  end

  include_examples 'compile'
  include_examples 'status' if ENV['SPEC_SHOW_STATUS']
  include_examples 'show_catalog' if ENV['SPEC_CATALOG_SHOW']
  include_examples 'console' if ENV['SPEC_RSPEC_CONSOLE']

  begin
    include_examples 'catalog'
  rescue ArgumentError
    true
  end

  begin
    include_examples 'common'
  rescue ArgumentError
    true
  end

  yield self if block_given?

end

alias :test_ubuntu_and_centos :run_test
alias :test_ubuntu :run_test
alias :test_centos :run_test
