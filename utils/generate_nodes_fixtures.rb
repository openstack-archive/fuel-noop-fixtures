#!/usr/bin/env ruby

require 'erb'

nodes    = []
ip       = ARGV[0].to_s || "10.20.0.100"
ip_tpl   = ip.split('.')[0,3].join('.')
ip_start = ip.split('.').last
nodenum = ARGV[1].to_i || 10

for i in 0..(nodenum.to_i - 1) do
  pk = ip_start.to_i + i
  node = {
    "ip"       => ip_tpl + "." + pk.to_s,
    "pk"       => pk,
    "id"       => pk,
    "main_mac" => (1..6).map{"%0.2x"%rand(256)}.join(":"),
    "nic2_mac" => (1..6).map{"%0.2x"%rand(256)}.join(":"),
    "nic3_mac" => (1..6).map{"%0.2x"%rand(256)}.join(":"),
    "nic4_mac" => (1..6).map{"%0.2x"%rand(256)}.join(":"),
    "nic5_mac" => (1..6).map{"%0.2x"%rand(256)}.join(":")
  }
  nodes << node
end

nodes_template = File.read("fixtures/nodes_template.erb")
renderer = ERB.new(nodes_template)
puts output = renderer.result()
