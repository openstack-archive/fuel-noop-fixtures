require 'spec_helper'
require 'noop/task'

describe Noop::Task do
  before(:each) do
    allow(Noop::Utils).to receive(:warning)
  end

  subject do
    Noop::Task.new 'my/test_spec.rb'
  end

  let (:root) do
    File.absolute_path File.join File.dirname(__FILE__), '..', '..'
  end

  context 'base' do
    it 'should have status' do
      is_expected.to respond_to :status
    end

    it 'should have success?' do
      subject.status = :pending
      is_expected.not_to be_success
      subject.status = :success
      is_expected.to be_success
    end

    it 'should have pending?' do
      subject.status = :failed
      is_expected.not_to be_pending
      subject.status = :pending
      is_expected.to be_pending
    end

    it 'should have failed?' do
      subject.status = :success
      is_expected.not_to be_failed
      subject.status = :failed
      is_expected.to be_failed
    end

    it 'should have parallel_run?' do
      is_expected.not_to be_parallel_run
      subject.parallel = true
      is_expected.to be_parallel_run
    end

    it 'should have valid?' do
      is_expected.to respond_to(:valid?)
    end

    it 'should have to_s' do
      expect(subject.to_s).to eq 'Task[my/test]'
    end

    it 'should have inspect' do
      expect(subject.inspect).to eq 'Task[Manifest: my/test.pp Spec: my/test_spec.rb Hiera: novanet-primary-controller.yaml Facts: ubuntu.yaml Status: pending]'
    end
  end

  context 'spec' do
    it 'has file_name_spec' do
      expect(subject.file_name_spec).to be_a Pathname
      expect(subject.file_name_spec.to_s).to eq 'my/test_spec.rb'
    end

    it 'can set file_name_spec' do
      subject.file_name_spec = 'my/test2_spec.rb'
      expect(subject.file_name_spec).to be_a Pathname
      expect(subject.file_name_spec.to_s).to eq 'my/test2_spec.rb'
    end

    it 'will get spec name from the manifest name' do
      subject.file_name_spec = 'my/test3.pp'
      expect(subject.file_name_spec).to be_a Pathname
      expect(subject.file_name_spec.to_s).to eq 'my/test3_spec.rb'
    end

    it 'has file_name_manifest' do
      expect(subject.file_name_manifest).to be_a Pathname
      expect(subject.file_name_manifest.to_s).to eq 'my/test.pp'
    end

    it 'has file_path_manifest' do
      expect(subject.file_path_manifest).to be_a Pathname
      expect(subject.file_path_manifest.to_s).to eq "#{root}/tasks/my/test.pp"
    end

    it 'has file_path_spec' do
      expect(subject.file_path_spec).to be_a Pathname
      expect(subject.file_path_spec.to_s).to eq "#{root}/spec/hosts/my/test_spec.rb"
    end
  end

  context 'facts' do
    it 'has file_name_facts' do
      expect(subject.file_name_facts).to be_a Pathname
      expect(subject.file_name_facts.to_s).to eq 'ubuntu.yaml'
    end

    it 'can set file_name_facts' do
      subject.file_name_facts = 'master.yaml'
      expect(subject.file_name_facts).to be_a Pathname
      expect(subject.file_name_facts.to_s).to eq 'master.yaml'
    end

    it 'will add yaml extension to the facts name' do
      subject.file_name_facts = 'centos'
      expect(subject.file_name_facts).to be_a Pathname
      expect(subject.file_name_facts.to_s).to eq 'centos.yaml'
    end

    it 'has file_path_facts' do
      expect(subject.file_path_facts).to be_a Pathname
      expect(subject.file_path_facts.to_s).to eq "#{root}/facts/ubuntu.yaml"
    end

    it 'has file_name_facts_override' do
      expect(subject.file_name_facts_override).to be_a Pathname
      expect(subject.file_name_facts_override.to_s).to eq 'my-test.yaml'
    end

    it 'has file_path_facts_override' do
      expect(subject.file_path_facts_override).to be_a Pathname
      expect(subject.file_path_facts_override.to_s).to eq "#{root}/facts/override/my-test.yaml"
    end
  end

  context 'hiera' do
    it 'has file_name_hiera' do
      expect(subject.file_name_hiera).to be_a Pathname
      expect(subject.file_name_hiera.to_s).to eq 'novanet-primary-controller.yaml'
    end

    it 'has file_base_hiera' do
      expect(subject.file_base_hiera).to be_a Pathname
      expect(subject.file_base_hiera.to_s).to eq 'novanet-primary-controller'
    end

    it 'has element_hiera' do
      expect(subject.element_hiera).to be_a Pathname
      expect(subject.element_hiera.to_s).to eq 'novanet-primary-controller'
    end

    it 'can set file_name_hiera' do
      subject.file_name_hiera = 'compute.yaml'
      expect(subject.file_name_hiera).to be_a Pathname
      expect(subject.file_name_hiera.to_s).to eq 'compute.yaml'
    end

    it 'will add yaml extension to the hiera name' do
      subject.file_name_hiera = 'controller'
      expect(subject.file_name_hiera).to be_a Pathname
      expect(subject.file_name_hiera.to_s).to eq 'controller.yaml'
    end

    it 'has file_path_hiera' do
      expect(subject.file_path_hiera).to be_a Pathname
      expect(subject.file_path_hiera.to_s).to eq "#{root}/hiera/novanet-primary-controller.yaml"
    end

    it 'has file_name_hiera_override' do
      expect(subject.file_name_hiera_override).to be_a Pathname
      expect(subject.file_name_hiera_override.to_s).to eq 'my-test.yaml'
    end

    it 'has file_path_hiera_override' do
      expect(subject.file_path_hiera_override).to be_a Pathname
      expect(subject.file_path_hiera_override.to_s).to eq "#{root}/hiera/override/my-test.yaml"
    end

    it 'has element_hiera_override' do
      expect(subject.element_hiera_override).to be_a Pathname
      expect(subject.element_hiera_override.to_s).to eq 'override/my-test'
    end

  end

  context 'globals' do
    it 'has file_path_globals' do
      expect(subject.file_path_globals).to be_a Pathname
      expect(subject.file_path_globals.to_s).to eq "#{root}/hiera/globals/novanet-primary-controller.yaml"
    end

    it 'has file_name_globals' do
      expect(subject.file_name_globals).to be_a Pathname
      expect(subject.file_name_globals.to_s).to eq 'novanet-primary-controller.yaml'
    end

    it 'has file_base_globals' do
      expect(subject.file_base_globals).to be_a Pathname
      expect(subject.file_base_globals.to_s).to eq 'novanet-primary-controller'
    end

    it 'has element_globals' do
      expect(subject.element_globals).to be_a Pathname
      expect(subject.element_globals.to_s).to eq 'globals/novanet-primary-controller'
    end
  end

  context 'validation' do
    context 'valid task' do
      before(:each) do
        allow(subject).to receive(:file_present_spec?).and_return true
        allow(subject).to receive(:file_present_manifest?).and_return true
        allow(subject).to receive(:file_present_hiera?).and_return true
        allow(subject).to receive(:file_present_facts?).and_return true
      end

      it 'should be valid' do
        subject.validate
        is_expected.to be_valid
      end

    end

    context 'spec is not set' do
      subject do
        Noop::Task.new
      end

      before(:each) do
        allow(Noop::Utils).to receive(:warning)
      end

      it 'should report unset spec' do
        is_expected.not_to be_file_name_spec_set
      end

      it 'should not be valid' do
        subject.validate
        is_expected.not_to be_valid
      end
    end

    context 'spec is set but missing' do

      it 'should NOT report unset spec' do
        is_expected.to be_file_name_spec_set
      end

      it 'should not be valid' do
        subject.validate
        is_expected.not_to be_valid
      end
    end

  end

end
