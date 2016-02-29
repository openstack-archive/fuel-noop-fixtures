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
      error "Could not load Puppet function '#{name}'!" unless puppet_scope.respond_to? "function_#{name}".to_sym
      puppet_scope.send "function_#{name}".to_sym, args
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
      puppet_scope.function_include [class_name] unless Noop.puppet_scope.catalog.classes.include? class_name
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

  end
end
