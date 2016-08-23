#!/bin/bash
#
# Use this script to generate and save astute.yaml fixtures.
# Should be executed on Fuel node with at least 7 discovered
# and unused (not assigned to any env) nodes.
#

mkdir -p ./yamls
rm -f ./yamls/*

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

function list_free_nodes {
  fuel2 node list 2>/dev/null | grep discover | grep None | awk '{print $2}'
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
    id=`id_of_role $1 $role`
    src="deployment_$1/${id}.yaml"
    cp $src ./yamls/$2-$role.yaml
    fix_node_names ./yamls/$2-$role.yaml
  done
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

function enable_vcenter {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["common"]["use_vcenter"]["value"] = true
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
}

function enable_vcenter_glance {
  fuel env --attributes --env $1 --download
  ruby -ryaml -e '
  attr = YAML.load(File.read(ARGV[0]))
  attr["editable"]["storage"]["images_vcenter"]["value"] = true
  File.open(ARGV[0], "w").write(attr.to_yaml)' "cluster_$1/attributes.yaml"
  fuel env --attributes --env $1 --upload
}

function vmware_settings {
  compute_vmware=$2
  fuel --env $1 vmware-settings --download
  ruby -ryaml -e '
  vmware = YAML.load(File.read(ARGV[0]))
  vcenter_cred = {
    "vcenter_host"=>"172.16.0.254", "vcenter_password"=>"Qwer!1234",
    "vcenter_username"=>"administrator@vsphere.local"
  }
  vmware["editable"]["value"]["availability_zones"][0].merge! vcenter_cred
  File.open(ARGV[0], "w").write(vmware.to_yaml)' "vmware_settings_$1.yaml"
  if [ "$compute_vmware" = "compute-vmware" ]; then
    env_id=`envid $1`
    node_id=$(list_free_nodes | sed -n '1p')
    fuel --env $env_id node set --node $node_id --role compute-vmware
    ruby -ryaml -e '
    $compute_vmware_node = ARGV[1]
    puts $compute_vmware_node
    vmware = YAML.load(File.read(ARGV[0]))
    vmware_computes = {
      "datastore_regex"=>".*", "service_name"=>"vm_cluster1",
      "target_node"=>{"current"=>{"id"=>$compute_vmware_node,
      "label"=>$compute_vmware_node}, "options"=>[{"id"=>"controllers",
      "label"=>"controllers"}, {"id"=>$compute_vmware_node,
      "label"=>$compute_vmware_node}]}, "vsphere_cluster"=>"Cluster1"
      }
    vmware["editable"]["value"]["availability_zones"][0]["nova_computes"][0].merge! vmware_computes
    File.open(ARGV[0], "w").write(vmware.to_yaml)' "vmware_settings_$1.yaml" "node-$node_id"
  else
    ruby -ryaml -e '
    vmware = YAML.load(File.read(ARGV[0]))
    vmware_computes = {
      "datastore_regex"=>".*", "service_name"=>"vm_cluster1",
      "target_node"=>{"current"=>{"id"=>"controllers",
      "label"=>"controllers"}, "options"=>[{"id"=>"controllers",
      "label"=>"controllers"}]}, "vsphere_cluster"=>"Cluster1"
      }
     vmware_glance = {
      "ca_file"=>{"content"=>"RSA", "name"=>"vcenter-ca.pem"},
      "datacenter"=>"Datacenter", "datastore"=>"nfs",
      "vcenter_host"=>"172.16.0.254", "vcenter_password"=>"Qwer!1234",
      "vcenter_username"=>"administrator@vsphere.local"
      }
    vmware["editable"]["value"]["availability_zones"][0]["nova_computes"][0].merge! vmware_computes
    vmware["editable"]["value"]["glance"].merge! vmware_glance
    File.open(ARGV[0], "w").write(vmware.to_yaml)' "vmware_settings_$1.yaml"
  fi
    fuel --env $1 vmware-settings --upload
}

function enable_vms_conf {
  virt_node_ids=`fuel nodes --env $1 2>/dev/null | grep virt | awk '{print $1}'`
  for id in $virt_node_ids ; do
    fuel2 node create-vms-conf $id --conf '{"id":3,"ram":2,"cpu":2}'
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
  if [ "${name/vmware.glance}" != "$name" ] ; then
    enable_vcenter $env
    enable_vcenter_glance $env
    vmware_settings $env
  fi
  if [ "${name/vmware.cinder-vmware.compute-vmware}" != "$name" ] ; then
    enable_vcenter $env
    vmware_settings $env compute-vmware
  fi

  for id in `list_free_nodes` ; do
    if ! [ -z "${roles[0]}" ] ; then
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
    rm -rf "vmware_settings_$env.yaml"
    sleep 60
  fi
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

# Neutron vlan VMware vCenter + VMware Glance
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_vlan.vmware.glance' 'controller controller controller' 'primary-controller'
clean_env 'test_neutron_vlan'

# Neutron vlan VMware vCenter + cinder-vmware + compute-vmware
fuel env --create --name test_neutron_vlan --rel 2 --net vlan
generate_yamls 'test_neutron_vlan' 'neut_vlan.vmware.cinder-vmware.compute-vmware' 'controller controller controller cinder-vmware' 'primary-controller compute-vmware cinder-vmware'
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

# Neutron tun + vms_conf
fuel env --create --name test_neutron_tun --rel 2 --net tun
generate_yamls 'test_neutron_tun' 'neut_tun.vms_conf' 'virt compute' 'virt'
clean_env 'test_neutron_tun'
