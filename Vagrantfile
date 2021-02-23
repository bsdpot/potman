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
  end

  config.vm.define "pottery", primary: false do |node|
    node.vm.hostname = 'minipot'
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
    #node.vm.network :private_network, ip: "192.168.56.101"
    #node.vm.network :forwarded_port, guest: 22, host: 10122, id: "ssh"
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
