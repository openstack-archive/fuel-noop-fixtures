module Noop
  class Task

    # Extract the parameter or property of a Puppet resource in the catalog
    # @param context [RSpec::ExampleGroup] The 'self' of the RSpec example group
    # @param resource_type [String] Name of the resource type
    # @param resource_name [String] Title of the resource
    # @param parameter [String] Parameter name
    # @return [Object]
    def resource_parameter_value(context, resource_type, resource_name, parameter)
      catalog = context.subject
      catalog = catalog.call if catalog.is_a? Proc
      resource = catalog.resource resource_type, resource_name
      error "No resource type: '#{resource_type}' name: '#{resource_name}' in the catalog!" unless resource
      resource[parameter.to_sym]
    end

    # Save the current puppet scope
    # @param value [Puppet::Scope]
    def puppet_scope=(value)
      @puppet_scope = value
    end

    # The saved Puppet scope to run functions in
    # Or the newly generated scope.
    # @return [Puppet::Scope]
    def puppet_scope
      return @puppet_scope if @puppet_scope
      PuppetlabsSpec::PuppetInternals.scope
    end

    # Load a puppet function if it's not already loaded
    # @param name [String] Function name
    def puppet_function_load(name)
      name = name.to_sym unless name.is_a? Symbol
      Puppet::Parser::Functions.autoloader.load name
    end

    # Call a puppet function and return it's value
    # @param name [String] Function name
    # @param *args [Object] Function parameters
    # @return [Object]
    def puppet_function(name, *args)
      name = name.to_sym unless name.is_a? Symbol
      puppet_function_load name
      if puppet4?
        puppet_scope.call_function name, args
      else
        error "Could not load Puppet function '#{name}'!" unless puppet_scope.respond_to? "function_#{name}".to_sym
        puppet_scope.send "function_#{name}".to_sym, args
      end
    end

    # Take a variable value from the saved puppet scope
    # @param name [String] variable name
    def lookupvar(name)
      puppet_scope.lookupvar name
    end
    alias :variable :lookupvar

    # Load a class from the Puppet modules into the current scope
    # It can be used to extract values from 'params' classes like this:
    # Noop.load_class 'nova::params'
    # Noop.variable 'nova::params::common_package_name'
    # => 'openstack-nova-common'
    # These values can be later used in the spec examples.
    # Note, that the loaded class will not be found in the spec's catalog
    # object, but can be found here: Noop.puppet_scope.catalog
    # @param class_name [String]
    def puppet_class_include(class_name)
      class_name = class_name.to_s
      unless puppet_scope.catalog.classes.include? class_name
        debug "Dynamically loading class: '#{class_name}'"
        puppet_scope.compiler.evaluate_classes [class_name], puppet_scope, false
      end
    end

    # Convert resource catalog to a RAL catalog
    # and run both "generate" functions for each resource
    # that has it and then add results to the catalog
    # @param context [RSpec::ExampleGroup] The 'self' of the RSpec example group
    # @return <Lambda>
    def create_ral_catalog(context)
      catalog = context.subject
      catalog = catalog.call if catalog.is_a? Proc
      ral_catalog = catalog.to_ral
      generate_functions = [:generate, :eval_generate]

      ral_catalog.resources.each do |resource|
        generate_functions.each do |function_name|
          next unless resource.respond_to? function_name
          generated = resource.send function_name
          next unless generated.is_a? Array
          generated.each do |generated_resource|
            next unless generated_resource.is_a? Puppet::Type
            ral_catalog.add_resource generated_resource
          end
        end
      end

      lambda { ral_catalog }
    end

    # Check if the currently running spec is the given one
    # or one of the given ones if an array is provided
    # @param spec [String, Array<String>]
    # @return [true,false]
    def current_spec_is?(spec)
      return false unless file_name_spec_set?
      spec = [spec] unless spec.is_a? Array
      spec = spec.flatten
      spec = spec.map do |spec|
        Noop::Utils.convert_to_spec spec
      end
      spec.any? do |spec|
        file_name_spec == spec
      end
    end

    # check if we're using Puppet4
    # @return [true,false]
    def puppet4?
      Puppet.version.to_f >= 4.0
    end

    # convert the values in the nested data structure
    # from nil to :undef as they are used in Puppet 4
    # modifies the argument object and returns it
    # @param data [Array, Hash]
    # @return [Array, Hash]
    def nil2undef(data)
      return :undef if data.nil?
      if data.is_a? Array
        data.each_with_index do |value, index|
          data[index] = nil2undef value
        end
        data
      elsif data.is_a? Hash
        data.keys.each do |key|
          data[key] = nil2undef data[key]
        end
        data
      end
      data
    end

  end
end
