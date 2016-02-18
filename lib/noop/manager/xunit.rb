require 'rexml/document'

module Noop
  class Manager

    # Generate a data structure that will be used to create the xUnit report
    # @return [Array]
    def tasks_report_structure
      tasks_report = []

      task_list.each do |task|
        task_hash = {}
        task_hash[:status] = task.status
        task_hash[:name] = task.to_s
        task_hash[:description] = task.description
        task_hash[:spec] = task.file_name_spec.to_s
        task_hash[:hiera] = task.file_name_hiera.to_s
        task_hash[:facts] = task.file_name_facts.to_s
        task_hash[:task] = task.file_name_manifest.to_s
        task_hash[:examples] = []

        if task.report.is_a? Hash
          examples = task.report['examples']
          next unless examples.is_a? Array
          examples.each do |example|
            example_hash = {}
            example_hash[:file_path] = example['file_path']
            example_hash[:line_number] = example['line_number']
            example_hash[:description] = example['description']
            example_hash[:status] = example['status']
            example_hash[:run_time] = example['run_time']
            example_hash[:pending_message] = example['pending_message']
            exception_class = example.fetch('exception', {}).fetch('class', nil)
            exception_message = example.fetch('exception', {}).fetch('message', nil)
            next unless example_hash[:description] and example_hash[:status]
            if exception_class and exception_message
              example_hash[:exception_class] = exception_class
              example_hash[:exception_message] = exception_message
            end
            task_hash[:examples] << example_hash
          end

          summary = task.report['summary']
          task_hash[:example_count] = summary['example_count']
          task_hash[:failure_count] = summary['failure_count']
          task_hash[:pending_count] = summary['pending_count']
          task_hash[:duration] = summary['duration']
        end

        tasks_report << task_hash
      end
      tasks_report
    end

    # Generate xUnit XML report text
    # @return [String]
    def xunit_report
      document = REXML::Document.new
      declaration = REXML::XMLDecl.new
      declaration.encoding = 'UTF-8'
      declaration.version = '1.0'
      document.add declaration
      testsuites = document.add_element 'testsuites'
      tests = 0
      failures = 0
      task_id = 0

      tasks_report_structure.each do |task|
        testsuite = testsuites.add_element 'testsuite'
        testsuite.add_attribute 'id', task_id
        task_id += 1
        testsuite.add_attribute 'name', task[:description]
        testsuite.add_attribute 'package', task[:name]
        testsuite.add_attribute 'tests', task[:example_count]
        testsuite.add_attribute 'failures', task[:failure_count]
        testsuite.add_attribute 'skipped', task[:pending_count]
        testsuite.add_attribute 'time', task[:duration]
        testsuite.add_attribute 'status', task[:status]

        properties = testsuite.add_element 'properties'
        property_task = properties.add_element 'property'
        property_task.add_attribute 'name', 'task'
        property_task.add_attribute 'value', task[:task]
        property_spec = properties.add_element 'property'
        property_spec.add_attribute 'name', 'spec'
        property_spec.add_attribute 'value', task[:spec]
        property_hiera = properties.add_element 'property'
        property_hiera.add_attribute 'name', 'hiera'
        property_hiera.add_attribute 'value', task[:hiera]
        property_facts = properties.add_element 'property'
        property_facts.add_attribute 'name', 'facts'
        property_facts.add_attribute 'value', task[:facts]

        if task[:examples].is_a? Array
          task[:examples].each do |example|
            tests += 1
            testcase = testsuite.add_element 'testcase'
            testcase.add_attribute 'name', example[:description]
            testcase.add_attribute 'classname', "#{example[:file_path]}:#{example[:line_number]}"
            testcase.add_attribute 'time', example[:run_time]
            testcase.add_attribute 'status', example[:status]
            if example[:status] == 'pending'
              skipped = testcase.add_element 'skipped'
              skipped.add_attribute 'message', example[:pending_message] if example[:pending_message]
            end
            if example[:status] == 'failed'
              failures += 1
            end
            if example[:exception_message] and example[:exception_class]
              failure = testcase.add_element 'failure'
              failure.add_attribute 'message', example[:exception_message]
              failure.add_attribute 'type', example[:exception_class]
            end
          end
        end
      end
      testsuites.add_attribute 'tests', tests
      testsuites.add_attribute 'failures', failures
      document.to_s
    end

    # xUnit report file name
    # @return [Pathname]
    def file_name_xunit_report
      Pathname.new 'report.xml'
    end

    # Full path to the xUnit report file
    # @return [Pathname]
    def file_path_xunit_report
      Noop::Config.dir_path_reports + file_name_xunit_report
    end

    # Write the xUnit report to the file
    # @return [void]
    def save_xunit_report
      File.open(file_path_xunit_report.to_s, 'w') do |file|
        file.puts xunit_report
      end
      Noop::Utils.debug "xUnit XML report was saved to: #{file_path_xunit_report.to_s}"
    end

  end
end
