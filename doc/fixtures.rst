.. _fuel_noop_fixtures:

Fuel Noop fixtures
==================

There is a separate `fuel-noop-fixtures`_ repository to store all of the
fixtures and libraries required for the noop tests execution.
This repository will be automatically fetched before the noop tests are run to
the *tests/noop/fuel-noop-fixtures* directory.

Developers of the noop tests can add new Hiera and facts yaml files into this
repository instead of the main `fuel-library`_ repository.

.. _fuel-noop-fixtures: https://github.com/openstack/fuel-noop-fixtures
.. _fuel-library: https://github.com/openstack/fuel-library
