Using the noop_tests utility
============================

The noop_tests options
----------------------

Noop tests framework is actually located in the fixtures repository together
with its yaml data files. There is a wrapper script *tests/noop/noop_tests.sh*
that can be used from the Fuel library repository to automatically setup the
external fixtures repository, configure paths and run the framework.

First, you can use the **-h** options to get the help output.::

  tests/noop/noop_tests.sh -h

Output:::

    Usage: noop_tests [options]
    Main options:
        -j, --jobs JOBS                  Parallel run RSpec jobs
        -g, --globals                    Run all globals tasks and update saved globals YAML files
        -B, --bundle_setup               Setup Ruby environment using Bundle
        -b, --bundle_exec                Use "bundle exec" to run rspec
        -l, --update-librarian           Run librarian-puppet update in the deployment directory prior to testing
        -L, --reset-librarian            Reset puppet modules to librarian versions in the deployment directory prior to testing
        -o, --report_only_failed         Show only failed tasks and examples in the report
        -O, --report_only_tasks          Show only tasks, skip individual examples
        -r, --load_saved_reports         Read saved report JSON files from the previous run and show tasks report
        -R, --run_failed_tasks           Run the task that have previously failed again
        -x, --xunit_report               Save report in xUnit format to a file
    List options:
        -Y, --list_hiera                 List all hiera yaml files
        -S, --list_specs                 List all task spec files
        -F, --list_facts                 List all facts yaml files
        -T, --list_tasks                 List all task manifest files
    Filter options:
        -s, --specs SPEC1,SPEC2          Run only these spec files. Example: "hosts/hosts_spec.rb,apache/apache_spec.rb"
        -y, --yamls YAML1,YAML2          Run only these hiera yamls. Example: "controller.yaml,compute.yaml"
        -f, --facts FACTS1,FACTS2        Run only these facts yamls. Example: "ubuntu.yaml,centos.yaml"
    Debug options:
        -c, --task_console               Run PRY console
        -C, --rspec_console              Run PRY console in the RSpec process
        -d, --task_debug                 Show framework debug messages
        -D, --puppet_debug               Show Puppet debug messages
            --debug_log FILE             Write all debug messages to this files
        -t, --self-check                 Perform self-check and diagnostic procedures
        -p, --pretend                    Show which tasks will be run without actually running them
    Path options:
            --dir_root DIR               Path to the test root folder
            --dir_deployment DIR         Path to the test deployment folder
            --dir_hiera_yamls DIR        Path to the folder with hiera files
            --dir_facts_yamls DIR        Path to the folder with facts yaml files
            --dir_spec_files DIR         Path to the folder with task spec files (changing this may break puppet-rspec)
            --dir_task_files DIR         Path to the folder with task manifest files
            --dir_puppet_modules DIR     Path to the puppet modules
    Spec options:
        -A, --catalog_show               Show catalog content debug output
        -V, --catalog_save               Save catalog to the files instead of comparing them with the current catalogs
        -v, --catalog_check              Check the saved catalog against the current one
        -a, --spec_status                Show spec status blocks
            --puppet_binary_files        Check if Puppet installs binary files
            --save_file_resources        Save file resources list to a report file

Shortcut scripts
----------------

There are also several shortcut scripts near the *noop_tests.sh* file that
can be used to perform some common actions.

- **tests/noop/noop_tests.sh** The main wrapper shell script. It downloads the
  fixtures repository, sets the correct paths and setups the Ruby gems. It's
  used by many other shortcut scripts.
- **utils/jenkins/fuel_noop_tests.sh** The wrapper script used as an entry point
  for the automated Jenkins CI jobs. Runs all tests in parallel mode.
- **tests/noop/run_all.sh** This wrapper will run all tests in parallel mode.
- **tests/noop/run_global.sh** This wrapper will run all globals tasks and save
  the generated globals yaml files.
- **tests/noop/setup_and_diagnostics.sh** This wrapper will first setup the
  Ruby environment, download Fuel Library modules and run the noop tests in the
  diagnostics mode to check the presence of all folders in the structure and
  the numbers of tasks in the library.
- **run_failed_tasks.sh** This wrapper will load the saved reports files from
  the previous run and will try to run all the failed tasks again.
- **purge_reports.sh** Removes all task report files.
- **purge_globals.sh** Removes all saved globals files.
- **purge_catalogs.sh** Removes all saves catalog files.
