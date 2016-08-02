#!/bin/bash
#
# Use this script to generate and save astute.yaml fixtures.
# Should be executed on Fuel node with 'advanced' feature enabled
# (see FEATURE_GROUPS list in /etc/nailgun/settings.yaml)

CWD=$(cd `dirname $0` && pwd -P)

mkdir ./yamls
rm -f ./yamls/*

function generate_fake_nodes_fixtures {
  # $1 - first IP of admin network to start generate nodes from
  # $2 - number of nodes to generate
  # $3 - name of fixture
  $CWD/generate_nodes_fixtures.rb $1 $2 > $CWD/fixtures/${3}.json
}

function create_fake_nodes {
  manage.py loaddata $CWD/fixtures/${1}.json
}

function clean_fake_nodes {
  fuel nodes | grep -q 'discover | fnode-' &&
    fuel nodes | awk '/discover \| fnode-/{ print $1 }' | xargs fuel node --delete-from-db --force --node
}

function admin_net_tpl {
  fuel network-group list | awk '/^1 /{print $9}' | sed -e 's/\.[[:digit:]]\+$//'
}

function id_of_role {
  env=$1
  role=$2
  yaml=`grep -rl node_roles: deployment_$env/*yaml | head -n1`
  ruby -ryaml -e '
  astute = YAML.load(File.read(ARGV[0]))
  role = ARGV[1]
  node = astute["network_metadata"]["nodes"].find{|key, hash| hash["node_roles"].include?("#{role}") }
  puts node.last["uid"]
  ' $yaml $role
}

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
  attr["editable"]["storage"]["auth_s3_keystone_ceph"]["value"] = true
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
  rm -rf "cluster_$1"
}

function enable_cblock {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["storage"]["volumes_block_device"]["value"] = true
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

function enable_nova_quota {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["common"]["nova_quota"]["value"] = true
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

function enable_vms_conf {
  virt_node_ids=`fuel nodes --env $1 2>/dev/null | grep virt | awk '{print $1}'`
  for id in $virt_node_ids ; do
    fuel2 node create-vms-conf $id --conf '{"id":3,"ram":2,"cpu":2}'
  done
}

function list_free_nodes {
  # list unused nodes from the list of fake nodes
  if [ -n "$1" ] ; then
    fuel nodes 2>/dev/null | grep discover | grep None | grep 'fnode-' | grep $1 | awk '{print $1}'
  else
    fuel nodes 2>/dev/null | grep discover | grep None | grep 'fnode-' | awk '{print $1}'
  fi
}

function save_yamls {
  envid=`fuel env | grep $1 | awk '{print $1}'`
  fuel deployment --default --env $envid 2>/dev/null
}

function envid {
  fuel env 2>/dev/null | grep $1 | awk '{print $1}'
}

function fix_node_names {
  file=$1
  ruby -ryaml -e '
  astute = YAML.load(File.read(ARGV[0]))
  astute["network_metadata"]["nodes"].each do |key, hash|
    wrong = hash["name"]
    puts "\"s/#{wrong}/#{key}/g\""
  end
  ' $file | xargs -I {} sed -e {} -i $file
}

function store_yamls {
  for role in $3 ; do
    id=`id_of_role $1 $role`
    src="deployment_$1/${id}.yaml"
    cp $src ./yamls/$2-$role.yaml
    fix_node_names ./yamls/$2-$role.yaml
  done
}

function generate_yamls {
  env=`envid $1`
  name=$2
  roles=($3)

  # Create fake nodes for our fixtures
  generate_fake_nodes_fixtures $admin_first_ip 10 default_nodegroup
  create_fake_nodes default_nodegroup

  if [ "${name/ceph}" != "$name" ] ; then
    enable_ceph $env
  fi
  if [ "${name/murano.sahara.ceil}" != "$name" ] ; then
    enable_murano_sahara_ceilometer $env
  fi
  if [ "${name/nova_quota}" != "$name" ] ; then
    enable_nova_quota $env
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
  if [ "${name/cblock}" != "$name" ] ; then
    enable_cblock $env
  fi

  if [ "${name/multirack}" != "$name" ] ; then
    # move controllers to custom node group
    for id in `list_free_nodes 9.9.9` ; do
      if [ "${roles[0]}" = "controller" ] ; then
        fuel --env $env node set --node $id --role ${roles[0]}
        roles=("${roles[@]:1}")
      fi
    done
  fi

  for id in `list_free_nodes` ; do
    if [ -n "${roles[0]}" ] ; then
      fuel --env $env node set --node $id --role ${roles[0]}
      roles=("${roles[@]:1}")
      sleep 1
    fi
  done

  #We need assigned "virt" role to enable vms_conf
  if [ "${name/vms_conf}" != "$name" ] ; then
    enable_vms_conf $env
  fi

  save_yamls $env
  store_yamls $env $name "$4"
}

function clean_env {
  env=`envid $1`
  if fuel env --env $env | grep $1 ; then
    fuel env --delete --env $env
    rm -rf "cluster_$env"
    rm -rf "deployment_$env"
    rm -f network_${env}.yaml
    sleep 80
  fi
  clean_fake_nodes
}

function add_nodegroup {
  env=`envid $1`
  name=$2

  fuel --env $env nodegroup --create --name $name
}

function update_default_nodegroup {
  env=`envid $1`
  fuel network --env $env download
  sed -e 's/172\.16\.0\./10.11.1./g' -i network_${env}.yaml
  sed -e 's/192\.168\.0\./10.11.2./g' -i network_${env}.yaml
  sed -e 's/192\.168\.1\./10.11.3./g' -i network_${env}.yaml
  sed -e 's/192\.168\.2\./10.11.4./g' -i network_${env}.yaml
  fuel network --env $env upload
}

clean_fake_nodes
sleep 1

# Get some context
admin_net=$(admin_net_tpl)
admin_first_ip="${admin_net}.100"

# Neutron vlan ceph
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_vlan.ceph' 'controller controller controller compute ceph-osd ceph-osd' 'primary-controller compute ceph-osd'
clean_env 'test_neutron_vlan'

# Neutron vlan addons
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_vlan.cblock.murano.sahara.ceil' 'controller controller compute mongo mongo cinder cinder-block-device' 'primary-controller controller compute primary-mongo mongo cinder cinder-block-device'
clean_env 'test_neutron_vlan'

# Neutron-dvr vlan
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_vlan.dvr' 'controller controller controller' 'primary-controller'
clean_env 'test_neutron_vlan'

# Neutron tun addons + ceph
fuel env --create --name test_neutron_tun --rel 2 --net tun
generate_yamls 'test_neutron_tun' 'neut_tun.ceph.murano.sahara.ceil' 'controller controller compute ceph-osd ceph-osd mongo mongo' 'primary-controller controller compute ceph-osd primary-mongo mongo'
clean_env 'test_neutron_tun'

# Neutron vlan ironic
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_tun.ironic' 'controller ironic' 'primary-controller ironic'
clean_env 'test_neutron_vlan'

# Neutron-l3ha tun + nova_quota
fuel env --create --name test_neutron_tun --rel 2 --net tun
generate_yamls 'test_neutron_tun' 'neut_tun.l3ha.nova_quota' 'controller controller controller' 'primary-controller'
clean_env 'test_neutron_tun'

# Neutron tun + vms_conf
fuel env --create --name test_neutron_tun --rel 2 --net tun
generate_yamls 'test_neutron_tun' 'neut_tun.vms_conf' 'virt compute' 'virt'
clean_env 'test_neutron_tun'

# Multirack, Neutron tun, addons, ceph, public and horizon ssl
fuel env --create --name test_neutron_tun --rel 2 --net tun
update_default_nodegroup 'test_neutron_tun'
add_nodegroup 'test_neutron_tun' 'custom_group1'
generate_fake_nodes_fixtures 9.9.9.150 5 custom_nodegroup
create_fake_nodes custom_nodegroup
generate_yamls 'test_neutron_tun' 'neut_tun.multirack.murano.sahara.ceil.ceph.public_ssl' 'controller controller controller mongo mongo compute ceph-osd ceph-osd' 'primary-controller compute ceph-osd primary-mongo'
clean_env 'test_neutron_tun'

