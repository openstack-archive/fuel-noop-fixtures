module Noop
  class Task
    attr_accessor :report

    # Generate the report of the currently using files in this spec
    # @return [String]
    def status_report(context)
      task = context.task
      template = <<-'eof'
Facts:    <%= task.file_path_facts %>
Hiera:    <%= task.file_path_hiera %>
Spec:     <%= task.file_path_spec %>
Manifest: <%= task.file_path_manifest %>

Node:     <%= task.hiera_lookup 'fqdn' or '?' %>
Role:     <%= task.hiera_lookup 'role' or '?' %>

Hiera hierarchy:
<% task.hiera_hierarchy.each do |element| -%>
* <%= element %>
<% end -%>

Facts hierarchy:
<% task.facts_hierarchy.reverse.each do |element| -%>
* <%= element %>
<% end -%>
      eof
      ERB.new(template, nil, '-').result(binding)
    end

    # Get a loaded gem version
    # @return [String,nil]
    def gem_version(gem)
      gem = gem.to_s
      return unless Object.const_defined? 'Gem'
      return unless Gem.loaded_specs.is_a? Hash
      return unless Gem.loaded_specs[gem].is_a? Gem::Specification
      Gem.loaded_specs[gem].version
    end

    # Gem a report about RSpec gems versions
    # @return [String]
    def gem_versions_report
      versions = "Ruby version: #{RUBY_VERSION}"
      %w(puppet rspec rspec-puppet rspec-puppet-utils puppetlabs_spec_helper).each do |gem|
        version = gem_version gem
        versions += "\n'#{gem}' gem version: #{version}"if version
      end
      versions
    end

    # Load a report file of this task if it's present
    def file_load_report_json
      self.report = file_data_report_json
    end

    # Check if this task has report loaded
    # @return [true,false]
    def has_report?
      report.is_a? Hash and report['examples'].is_a? Array
    end

    # @return [Pathname]
    def file_name_report_json
      Noop::Utils.convert_to_path "#{file_name_base_task_report}.json"
    end

    # @return [Pathname]
    def file_path_report_json
      Noop::Config.dir_path_reports + file_name_report_json
    end

    # @return [Hash]
    def file_data_report_json
      return unless file_present_report_json?
      file_data = nil
      begin
        # debug "Reading report file: #{file_path_report_json}"
        file_content = File.read file_path_report_json.to_s
        file_data = JSON.load file_content
        return unless file_data.is_a? Hash
      rescue
        debug "Error parsing report file: #{file_path_report_json}"
        nil
      end
      file_data
    end

    # Remove the report file
    def file_remove_report_json
      #debug "Removing report file: #{file_path_report_json}"
      file_path_report_json.unlink if file_present_report_json?
    end

    # @return [true,false]
    def file_present_report_json?
      file_path_report_json.exist?
    end
  end
end
