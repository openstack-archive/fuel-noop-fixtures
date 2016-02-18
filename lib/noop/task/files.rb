module Noop
  class Task
    # @return [Pathname]
    def dir_name_file_reports
      Pathname.new 'files'
    end

    # @return [Pathname]
    def dir_path_file_reports
      Noop::Config.dir_path_reports + dir_name_file_reports
    end

    # @return [Pathname]
    def file_name_file_report
      file_name_base_task_report.sub_ext '.yaml'
    end

    # @return [Pathname]
    def file_path_file_report
      dir_path_file_reports + file_name_file_report
    end

    # @return [Array<Puppet::Type>]
    def find_file_resources(context)
      catalog = context.subject
      catalog = catalog.call if catalog.is_a? Proc
      catalog.resources.select do |resource|
        resource.type == 'File'
      end
    end

    # @return [Hash]
    def catalog_file_report_structure(context)
      files = {}
      find_file_resources(context).each do |resource|
        next unless %w(present file directory).include? resource[:ensure] or not resource[:ensure]
        if resource[:source]
          content = resource[:source]
        elsif resource[:content]
          content = 'TEMPLATE'
        else
          content = nil
        end
        next unless content
        files[resource[:path]] = content
      end
      files
    end

    # @return [String]
    def catalog_file_report_template(binding)
      template = <<-'eos'
<% if binary_files.any? -%>
You have <%= binary_files.length -%> files that are either binary or init.d scripts:
<% binary_files.each do |file| -%>
* <%= file %>
<% end -%>
<% end -%>
<% if downloaded_files.any? -%>
You are downloading <%= downloaded_files.length -%> files using File resource's source property:
<% downloaded_files.each do |file| -%>
* <%= file %>
<% end -%>
<% end -%>
eos
      ERB.new(template, nil, '-').result(binding)
    end

    # @return [void]
    def catalog_file_resources_check(context)
      binary_files_regexp = %r{^/bin|^/usr/bin|^/usr/local/bin|^/usr/sbin|^/sbin|^/usr/lib|^/usr/share|^/etc/init.d|^/usr/local/sbin|^/etc/rc\S\.d}
      binary_files = []
      downloaded_files = []
      find_file_resources(context).each do |resource|
        next unless %w(present file directory).include? resource[:ensure] or not resource[:ensure]
        file_path = resource[:path] or resource[:title]
        file_source = resource[:source]
        binary_files << file_path if file_path =~ binary_files_regexp
        downloaded_files << file_path if file_source
      end
      if binary_files.any? or downloaded_files.any?
        Noop::Utils.output Noop::Utils.separator
        Noop::Utils.output catalog_file_report_template(binding)
        Noop::Utils.output Noop::Utils.separator
        fail 'Puppet is installing files that should be packed to the Fuel package!'
      end
    end

    # @return [void]
    def catalog_file_report_write(context)
      dir_path_file_reports.mkpath
      Noop::Utils.error "File report directory '#{dir_path_file_reports}' doesn't exist!" unless dir_path_file_reports.directory?
      File.open(file_path_file_report.to_s, 'w') do |file|
        YAML.dump catalog_file_report_structure(context), file
      end
      Noop::Utils.debug "File resources list was saved to: #{file_path_file_report.to_s}"
    end

  end
end
