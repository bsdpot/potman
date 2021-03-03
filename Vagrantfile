# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define "potbuilder", primary: false do |node|
    node.vm.hostname = 'potbuilder'
    node.vm.box = "FreeBSD-12.2-RELEASE-amd64"
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "1"
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["setextradata", :id, 
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = 'virtio'
    end
  end

  config.vm.define "minipot", primary: true do |node|
    node.vm.hostname = 'minipot'
    node.vm.box = "FreeBSD-12.2-RELEASE-amd64"
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "1"
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["setextradata", :id, 
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = 'virtio'
    end
    #node.vm.network :private_network, ip: "10.100.1.3"
    node.vm.network :forwarded_port, guest: 4646, host_ip: "10.100.1.1",
      host: 4646, id: "nomad"
    node.vm.network :forwarded_port, guest: 8500, host_ip: "10.100.1.1",
      host: 8500, id: "consul"
    node.vm.network :forwarded_port, guest: 8080, host_ip: "10.100.1.1",
      host: 8080, id: "www"
    node.vm.network :forwarded_port, guest: 9002, host_ip: "10.100.1.1",
      host: 9002, id: "traefik"
  end

  config.vm.define "pottery", primary: false do |node|
    node.vm.hostname = 'pottery'
    node.vm.box = "FreeBSD-12.2-RELEASE-amd64"
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = "1"
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["setextradata", :id, 
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = 'virtio'
    end

    node.vm.network :private_network, ip: "10.100.1.2"
    node.vm.network :forwarded_port, guest: 80, host_ip: "10.100.1.1", host: 10180, id: "www"
    #node.vm.provision :hosts, :sync_hosts => true

    node.vm.provision 'ansible' do |ansible|
      ansible.compatibility_mode = '2.0'
      ansible.limit = 'all'
      ansible.playbook = 'site.yml'
      ansible.become = true
      ansible.groups = {
        "all" => ["potbuilder", "minipot", "pottery"],
        "all:vars" => {
          "ansible_python_interpreter" => "/usr/local/bin/python"
        },
      }
    end
  end
end
