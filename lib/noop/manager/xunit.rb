module Noop
  class Manager
    def xunit_report(tasks)
      tasks_report = tasks_report_structure tasks
      return unless tasks_report.is_a? Array
      document = REXML::Document.new
      declaration = REXML::XMLDecl.new
      declaration.encoding = 'UTF-8'
      declaration.version = '1.0'
      document.add declaration
      testsuites = document.add_element 'testsuites'
      tests = 0
      failures = 0
      task_id = 0

      tasks_report.each do |task|
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

    def file_name_xunit_report
      Pathname.new 'report.xml'
    end

    def file_path_xunit_report
      Noop::Config.dir_path_reports + file_name_xunit_report
    end

    def save_xunit_report
      File.open(file_path_xunit_report.to_s, 'w') do |file|
        file.puts xunit_report task_list
      end
      Noop::Utils.debug "xUnit XML report was saved to: #{file_path_xunit_report.to_s}"
    end

  end
end
