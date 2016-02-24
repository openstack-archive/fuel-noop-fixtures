shared_examples 'compile' do
  it { is_expected.to compile }
end

shared_examples 'show_catalog' do
  it 'shows catalog contents' do
    Noop::Utils.output Noop::Utils.separator
    Noop::Utils.output Noop.task.catalog_dump self
    Noop::Utils.output Noop::Utils.separator
  end
end

shared_examples 'status' do
  it 'shows status' do
    Noop::Utils.output Noop::Utils.separator
    Noop::Utils.output Noop.task.status_report self
    Noop::Utils.output Noop::Utils.separator
    Noop::Utils.output Noop.task.gem_versions_report
    Noop::Utils.output Noop::Utils.separator
  end
end

shared_examples 'files_installed_by_puppet' do
  it 'should check that binary files are not installed by this task' do
    Noop.catalog_file_resources_check self
  end
end

shared_examples 'save_files_list' do
  it 'should save the list of File resources to the file' do
    Noop.catalog_file_report_write self
  end
end

shared_examples 'saved_catalog' do
  it 'should save the current task catalog to the file', :if => (ENV['SPEC_CATALOG_CHECK'] == 'save') do
    Noop.file_write_task_catalog self
  end
  it 'should check the current task catalog against the saved one', :if => (ENV['SPEC_CATALOG_CHECK'] == 'check')  do
    saved_catalog = Noop.preprocess_catalog_data Noop.file_read_task_catalog
    current_catalog = Noop.preprocess_catalog_data Noop.catalog_dump self
    expect(saved_catalog).to eq current_catalog
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
  include_examples 'files_installed_by_puppet' if ENV['SPEC_PUPPET_BINARY_FILES']
  include_examples 'save_files_list' if ENV['SPEC_SAVE_FILE_RESOURCES']
  include_examples 'saved_catalog' if ENV['SPEC_CATALOG_CHECK']

  begin
    include_examples 'catalog'
  rescue ArgumentError
    true
  end

  yield self if block_given?

end

alias :test_ubuntu_and_centos :run_test
alias :test_ubuntu :run_test
alias :test_centos :run_test
