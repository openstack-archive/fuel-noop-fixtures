# fuel-noop-fixtures
--------------

## Table of Contents

1. [Overview - What is the fuel-noop-fixtures?](#overview)
2. [Structure - What is in the fuel-noop-fixtures?](#structure)
3. [Development](#development)
4. [Core Reviers](#core-reviewers)
5. [Contributors](#contributors)

## Overview
-----------

The fuel-noop-fixtures is a helper repo to store fixtures for Fuel Noop tests.

## Structure
------------

### Basic Repository Layout

```
fuel-noop-fixtures
├── LICENSE
├── README.md
├── catalogs
├── hiera
├── facts
```

### root

The root level contains important repository documentation and license
information.

### catalogs

The catalogs directory contains a committed state of Fuel Library deployment
data fixtures used for
[data regression checks](https://blueprints.launchpad.net/fuel/+spec/deployment-data-dryrun)

### astute.yaml

This directory contains hiera data templates for
[Fuel Library Noop tests](https://github.com/openstack/fuel-library/tree/master/tests/noop)

## Development
--------------

* [Fuel How to Contribute](https://wiki.openstack.org/wiki/Fuel/How_to_contribute)

## Core Reviewers
-----------------

* [Fuel Noop Fixtures Cores](https://review.openstack.org/#/admin/groups/1205,members)

## Contributors
---------------

* [Stackalytics](http://stackalytics.com/?release=all&project_type=all&module=fuel-noop-fixtures&metric=commits)
