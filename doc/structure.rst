Structure
=========

Data files
----------

To run a noop test on a spec following files are required:

- A spec file: *(i.e. spec/hosts/my/my_spec.rb)*
- A task file: *(i.e. modular/my/my.pp)*
- One of the Facts sets: *(i.e. ubuntu.yaml)*
- One of the Hiera files: *(i.e. neut_vlan.ceph.controller-ephemeral-ceph.yaml)*

Any single task is a combination of three attributes: spec file, yaml file
and facts file. Manifest file name and location will be determined automatically
based on the spec file. RSpec framework will try to compile the Puppet catalog
using the manifest file and modules from the module path. It will use the facts
from the facts file and the Hiera data from the hiera file.

If the spec is empty it will test only that catalog have compiled without any
errors. It's actually not a bad thing because even empty specs can catch most of
basic errors and problems. But if the spec has a **shared_examples 'catalog'**
block defined and there are several examples present they will be run against
the compiled catalog and the matchers will be used to determine if examples
pass or not.

Every Hiera yaml file also has a corresponding *globals* yaml file that contains
additional processed variables. These files are also used by most of the spec
tests. If you make any changes to the hiera yaml files you should also recreate
globals files by running *globals/globals* specs with *save globals* option
enabled. Later new files can be commited into the fixtures repository.

And, finally, there is an override system for hiera and facts yaml files.
For each spec file you can create a hiera or facts yaml file with a special
name. This file will be used on top of other files hierarchy. It can be very
useful in cases when you need to provide some custom data which is relevant
only for the one task you are working with without touching any other tasks.

Framework components
--------------------

The Noop test framework consists of the three components: the task manager,
the config and the task.

The task manager is responsible for collecting the
information about the present files, manipulation the task library, processing
the console options and environment variables and, finally, running the
tasks using the tasks objects and processing reports.

The config object contains the basic information about directory structure
and some default values and the values passed fro the external environment
variables. This object is static and is persistent between the instances of
all other objects.

The task object is the instance of a single test run. It can work with spec,
manifest, Hiera and facts yaml paths and run the actual RSpec command to
start the test.

The similar instance of the task process will be created inside
the RSpec process namespace and will be used to provide the information about
the current task as well as providing many different helpers and features
for the spec users. This object can be accessed through the proxy method of
the root **Noop** object which keep the reference to the current task instance.
