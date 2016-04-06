#!/bin/bash
#
# Use this script to generate and save astute.yaml fixtures.
# Should be executed on Fuel node with at least 7 discovered
# and unused (not assigned to any env) nodes.
#

mkdir ./yamls
rm -f ./yamls/*

function enable_ceph {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["storage"]["images_ceph"]["value"] = true
  attr["editable"]["storage"]["objects_ceph"]["value"] = true
  attr["editable"]["storage"]["volumes_ceph"]["value"] = true
  attr["editable"]["storage"]["ephemeral_ceph"]["value"] = true
  attr["editable"]["storage"]["volumes_lvm"]["value"] = false
  attr["editable"]["storage"]["osd_pool_size"]["value"] = "2"
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
  rm -rf "cluster_$1"
}

function enable_murano_sahara_ceilometer {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["additional_components"]["sahara"]["value"] = true
  attr["editable"]["additional_components"]["murano"]["value"] = true
  attr["editable"]["additional_components"]["ceilometer"]["value"] = true
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
}

function enable_ironic {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["additional_components"]["ironic"]["value"] = true
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
}

function enable_neutron_l3ha {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["neutron_advanced_configuration"]["neutron_l3_ha"]["value"] = true
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
}

function enable_neutron_dvr {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["neutron_advanced_configuration"]["neutron_dvr"]["value"] = true
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
}

function enable_public_ssl {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["public_ssl"]["services"]["value"] = true
  attr["editable"]["public_ssl"]["horizon"]["value"] = true
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
}

function list_free_nodes {
  fuel nodes 2>/dev/null | grep discover | grep None | awk '{print $1}'
}

function save_yamls {
  envid=`fuel env | grep $1 | awk '{print $1}'`
  fuel deployment --default --env $envid 2>/dev/null
}

function envid {
  fuel env 2>/dev/null | grep $1 | awk '{print $1}'
}

function store_yamls {
  for role in $3 ; do
    src=`ls deployment_$1/${role}_*.yaml | head -n1`
    cp $src ./yamls/$2-$role.yaml
  done
}

function generate_yamls {
  env=`envid $1`
  name=$2
  roles=($3)

  if [ "${name/ceph}" != "$name" ] ; then
    enable_ceph $env
  fi
  if [ "${name/murano.sahara.ceil}" != "$name" ] ; then
    enable_murano_sahara_ceilometer $env
  fi
  if [ "${name/ironic}" != "$name" ] ; then
    enable_ironic $env
  fi
  if [ "${name/l3ha}" != "$name" ] ; then
    enable_neutron_l3ha $env
  fi
  if [ "${name/dvr}" != "$name" ] ; then
    enable_neutron_dvr $env
  fi
  if [ "${name/public_ssl}" != "$name" ] ; then
    enable_public_ssl $env
  fi

  for id in `list_free_nodes` ; do
    if ! [ -z "${roles[0]}" ] ; then
      fuel --env $env node set --node $id --role ${roles[0]}
      roles=("${roles[@]:1}")
      sleep 1
    fi
  done
  save_yamls $env
  store_yamls $env $name "$4"
}

function clean_env {
  env=`envid $1`
  fuel env --delete --env $env
  rm -rf "cluster_$1"
  rm -rf "deployment_$env"
  sleep 80
}

# Neutron vlan ceph
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_vlan.ceph' 'controller controller controller compute ceph-osd ceph-osd' 'primary-controller compute ceph-osd'
clean_env 'test_neutron_vlan'

# Neutron vlan addons
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_vlan.murano.sahara.ceil' 'controller controller compute mongo mongo cinder cinder-block-device' 'primary-controller controller compute primary-mongo mongo cinder cinder-block-device'
clean_env 'test_neutron_vlan'

# Neutron-dvr vlan
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_vlan.dvr' 'controller controller controller' 'primary-controller'
clean_env 'test_neutron_vlan'

# Neutron tun addons + ceph
fuel env --create --name test_neutron_tun --rel 2 --net tun
generate_yamls 'test_neutron_tun' 'neut_tun.ceph.murano.sahara.ceil' 'controller controller compute ceph-osd ceph-osd mongo mongo' 'primary-controller controller compute ceph-osd primary-mongo mongo'
clean_env 'test_neutron_tun'

# Neutron tun ironic
fuel env --create --name test_neutron_tun --rel 2 --net tun
generate_yamls 'test_neutron_tun' 'neut_tun.ironic' 'controller ironic' 'primary-controller ironic'
clean_env 'test_neutron_tun'

# Neutron-l3ha tun
fuel env --create --name test_neutron_tun --rel 2 --net tun
generate_yamls 'test_neutron_tun' 'neut_tun.l3ha' 'controller controller controller' 'primary-controller'
clean_env 'test_neutron_tun'

# Neutron tun, addons, ceph, public and hotizon ssl
fuel env --create --name test_neutron_tun --rel 2 --net tun
generate_yamls 'test_neutron_tun' 'neut_tun.murano.sahara.ceil.public_ssl' 'controller controller mongo mongo compute ceph-osd ceph-osd' 'primary-controller compute ceph-osd primary-mongo'
clean_env 'test_neutron_tun'
