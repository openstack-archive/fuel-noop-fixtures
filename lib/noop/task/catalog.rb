require 'erb'

module Noop
  class Task

    # Dumps the entire catalog structure to the text
    # representation in the Puppet language
    # @param context [Object] the context from the rspec test
    # @param resources_filter [Array] the list of resources to dump. Dump all resources if not given
    def catalog_dump(context, resources_filter = [])
      catalog = context.subject
      catalog = catalog.call if catalog.is_a? Proc
      text = ''
      resources_filter = [resources_filter] unless resources_filter.is_a? Array
      catalog.resources.select do |catalog_resource|
        if catalog_resource.type == 'Class'
          next false if %w(main Settings).include? catalog_resource.title.to_s
        end
        next true unless resources_filter.any?
        resources_filter.find do |filter_resource|
          resources_are_same? catalog_resource, filter_resource
        end
      end.sort_by do |catalog_resource|
        catalog_resource.to_s
      end.each do |catalog_resource|
        text += dump_resource(catalog_resource) + "\n"
        text += "\n"
      end
      text
    end

    # Takes a parameter value and formats it to the literal value
    # that could be placed in the Puppet manifest
    # @param value [String, Array, Hash, true, false, nil]
    # @return [String]
    def parameter_value_format(value)
      case value
        when TrueClass then 'true'
        when FalseClass then 'false'
        when NilClass then 'undef'
        when Array then begin
          array = value.collect do |v|
            parameter_value_format v
          end.join(', ')
          "[ #{array} ]"
        end
        when Hash then begin
          hash = value.keys.sort do |a, b|
            a.to_s <=> b.to_s
          end.collect do |key|
            "#{parameter_value_format key.to_s} => #{parameter_value_format value[key]}"
          end.join(', ')
          "{ #{hash} }"
        end
        when Numeric, Symbol then parameter_value_format value.to_s
        when String then begin
                           # escapes single quote characters and wrap into them
          "'#{value.gsub "'", '\\\\\''}'"
        end
        else value.to_s
      end
    end

    # Take a resource object and generate a manifest representation of it
    # in the Puppet language. Replaces "to_manifest" Puppet function which
    # is not working correctly.
    # @param resource [Puppet::Resource]
    # @return [String]
    def dump_resource(resource)
      return '' unless resource.is_a? Puppet::Resource or resource.is_a? Puppet::Parser::Resource
      attributes = resource.keys
      if attributes.include?(:name) and resource[:name] == resource[:title]
        attributes.delete(:name)
      end
      attribute_max_length = attributes.inject(0) do |max_length, attribute|
        attribute.to_s.length > max_length ? attribute.to_s.length : max_length
      end
      attributes.sort!
      if attributes.first != :ensure && attributes.include?(:ensure)
        attributes.delete(:ensure)
        attributes.unshift(:ensure)
      end
      attributes_text_block = attributes.map { |attribute|
        value = resource[attribute]
        "  #{attribute.to_s.ljust attribute_max_length} => #{parameter_value_format value},\n"
      }.join
      "#{resource.type.to_s.downcase} { '#{resource.title.to_s}' :\n#{attributes_text_block}}"
    end

    # This function preprocesses both saved and generated
    # catalogs before they will be compared. It allows us to ignore
    # irrelevant changes in the catalogs:
    # * ignore trailing whitespaces
    # * ignore empty lines
    # @param data [String]
    # @return [String]
    def preprocess_catalog_data(data)
      clear_data = []
      data.to_s.split("\n").each do |line|
        line = line.rstrip
        next if line == ''
        clear_data << line
      end
      clear_data.join "\n"
    end

    # Check if two resources have same type and title
    # @param res1 [Puppet::Resource]
    # @param res2 [Puppet::Resource]
    # @return [TrueClass, False,Class]
    def resources_are_same?(res1, res2)
      res1 = res1.to_s.downcase.gsub %r|'"|, ''
      res2 = res2.to_s.downcase.gsub %r|'"|, ''
      res1 == res2
    end

    # @return [Pathname]
    def dir_name_catalogs
      Pathname.new 'catalogs'
    end

    # @return [Pathname]
    def dir_path_catalogs
      Noop::Config.dir_path_root + dir_name_catalogs
    end

    # @return [Pathname]
    def file_name_task_catalog
      Noop::Utils.convert_to_path "#{file_name_base_task_report}.pp"
    end

    # @return [Pathname]
    def file_path_task_catalog
      dir_path_catalogs + file_name_task_catalog
    end

    # Write the catalog file of this task
    # using the data from RSpec context
    # @param context [Object] the context from the rspec test
    # @return [void]
    def file_write_task_catalog(context)
      dir_path_catalogs.mkpath
      error "Catalog directory '#{dir_path_catalogs}' doesn't exist!" unless dir_path_catalogs.directory?
      debug "Writing catalog file: #{file_path_task_catalog}"
      File.open(file_path_task_catalog.to_s, 'w') do |file|
        file.puts catalog_dump context
      end
    end

    # Check if the catalog file exists for this task
    # @return [true,false]
    def file_present_task_catalog?
      file_path_task_catalog.file?
    end

    # Read the catalog file of this task
    # @return [String]
    def file_read_task_catalog
      return unless file_present_task_catalog?
      debug "Reading catalog file: #{file_path_task_catalog}"
      file_path_task_catalog.read
    end

  end
end
