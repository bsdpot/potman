#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

usage()
{
  echo "Usage: potman init [-hv] [-d flavourdir] [-n network] [-r freebsd_version] kiln_name

    flavourdir defaults to 'flavours'
    network defaults to '10.100.1'
    freebd_version defaults to '13.2'
"
}

FREEBSD_VERSION=13.2
FLAVOURS_DIR=flavours

OPTIND=1
while getopts "hvd:n:r:" _o ; do
  case "$_o" in
  d)
    FLAVOURS_DIR="${OPTARG}"
    ;;
  h)
    usage
    exit 0
    ;;
  v)
    VERBOSE="YES"
    ;;
  n)
    NETWORK="${OPTARG}"
    ;;
  r)
    FREEBSD_VERSION="${OPTARG}"
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

shift "$((OPTIND-1))"

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

NETWORK="$(echo "${NETWORK:=10.100.1}" | awk -F\. '{ print $1"."$2"."$3 }')"
KILN_NAME="$1"

set -eE
trap 'echo error: $STEP failed' ERR
source "${INCLUDE_DIR}/common.sh"
common_init_vars

set -eE
trap 'echo error: $STEP failed' ERR

if [ -z "${KILN_NAME}" ] || [ -z "${FREEBSD_VERSION}" ]; then
  usage
  exit 1
fi

if [[ ! "${KILN_NAME}" =~ $KILN_NAME_REGEX ]]; then
  >&2 echo "invalid kiln name $KILN_NAME"
  exit 1
fi

if [[ ! "${FREEBSD_VERSION}" =~ $FREEBSD_VERSION_REGEX ]]; then
  >&2 echo "unsupported freebsd version $FREEBSD_VERSION"
  exit 1
fi

if [[ ! "${NETWORK}" =~ $NETWORK_REGEX ]]; then
  >&2 echo "ivalid network $NETWORK (expecting A.B.C, e.g. 10.100.1)"
  exit 1
fi

step "Init kiln"
mkdir "$KILN_NAME"
git init "$KILN_NAME" >/dev/null
cd "$KILN_NAME"
if [ "$(git branch --show-current)" = "master" ]; then
  git branch -m master main
fi

if [ "${FLAVOURS_DIR}" = "flavours" ]; then
  mkdir flavours
  echo "Place your flavours in this directory" >flavours/README.md
fi

cat >site.yml<<"EOF"
---

- hosts: all
  tasks:
  - name: Install common packages
    ansible.builtin.package:
      name:
        - curl
        - joe
        - nano
        - vim-tiny
      state: present

- hosts: potbuilder
  tasks:

  - name: Disable coredumps
    sysctl:
      name: kern.coredump
      value: '0'

  - name: Create pkg config directory
    file: path=/usr/local/etc/pkg/repos state=directory mode=0755

  - name: Create pkg config
    copy:
      dest: /usr/local/etc/pkg/repos/FreeBSD.conf
      content: |
        FreeBSD: { url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest" }

  - name: Update package metadata
    ansible.builtin.command: pkg update -f

  - name: Upgrade existing packages (incl. pkg)
    ansible.builtin.command: pkg upgrade -y

  - name: Install packages
    ansible.builtin.package:
      name:
        - pot
      state: present

  - name: Create pot.conf
    copy:
      dest: /usr/local/etc/pot/pot.conf
      content: |
        POT_NETWORK=10.192.0.0/10
        POT_NETMASK=255.192.0.0
        POT_GATEWAY=10.192.0.1
        POT_EXTIF=vtnet0

  - name: Set flavours directory permissions
    ansible.builtin.file:
      path: /usr/local/etc/pot/flavours
      state: directory
      mode: '0775'

  - name: Run pot init
    ansible.builtin.command:
      argv:
        - /usr/local/bin/pot
        - init
      creates: /var/log/pot

- hosts: pottery
  tasks:
  - name: Install packages
    ansible.builtin.package:
      name:
        - nginx
      state: present

  - name: Enable nginx on boot
    ansible.builtin.service:
      name: nginx
      enabled: yes

  - name: Create pottery directory
    ansible.builtin.file:
      path: /usr/local/www/pottery
      state: directory
      mode: '0775'

  - name: Create pottery.tmp directory
    ansible.builtin.file:
      path: /usr/local/www/pottery.tmp
      state: directory
      mode: '0775'

  - name: Create nginx.conf
    copy:
      dest: /usr/local/etc/nginx/nginx.conf
      content: |
        worker_processes  1;
        events {
          worker_connections  1024;
        }
        http {
            server_tokens off;
            include       mime.types;
            charset       utf-8;
            server {
                server_name   localhost;
                listen        80;
                error_page    500 502 503 504  /50x.html;
                location      / {
                    root      /usr/local/www/pottery;
                    autoindex on;
                }
                location = /index.html {
                    rewrite   ^/index.html$ / last;
                }
                location = /index.json {
                    rewrite   ^/index.json$ / break;
                    root      /usr/local/www/pottery;
                    autoindex on;
                    autoindex_format json;
                }
                location = /50x.html {
                  root        /usr/local/www/nginx-dist;
                }
            }
        }
    notify:
      - Restart nginx

  handlers:
  - name: Restart nginx
    ansible.builtin.service:
      name: nginx
      state: restarted

- hosts: minipot
  tasks:
  - name: Install packages
    ansible.builtin.package:
      name:
        - minipot
        - vault
      state: present

  - name: Fix nomad path permission
    ansible.builtin.file:
      path: /var/tmp/nomad
      state: directory
      mode: '0700'

  - name: Download minipot-traefik.toml
    get_url:
      url: "https://raw.githubusercontent.com/pizzamig/minipot/\
        5ea810557ac20df14daf2072579455b4a4774471/etc/\
        minipot-traefik.toml.sample"
      dest: /usr/local/etc/minipot-traefik.toml
      checksum: "sha256:\
        acdc098a5abd20a0b85b7c1df6a74c9e3f7b529d62dad517cff40e153ae24f29"
      mode: '0644'

  - name: Create pot.conf
    copy:
      dest: /usr/local/etc/pot/pot.conf
      content: |
        POT_NETWORK=10.192.0.0/10
        POT_NETMASK=255.192.0.0
        POT_GATEWAY=10.192.0.1
        POT_EXTIF=vtnet0

  - name: Run pot init
    ansible.builtin.command:
      argv:
        - /usr/local/bin/pot
        - init
      creates: /var/log/pot

  - name: Run minipot-init
    ansible.builtin.command:
      argv:
        - /usr/local/bin/minipot-init
      creates: /var/log/nomad/nomad.log

    notify:
      - Restart nomad
      - Restart consul
      - Restart traefik

  - name: Create extra consul config
    copy:
      dest: /usr/local/etc/consul.d/minipot-agent_extra.json
      content: !unsafe |
        {
          "bind_addr": "{{ GetInterfaceIP \"vtnet1\" }}",
          "limits": {
              "http_max_conns_per_client": 10000
           }
        }

    notify:
      - Restart consul

  - name: Update nomad_args sysrc
    ansible.builtin.command: sysrc nomad_args+=" -data-dir=/var/tmp/nomad"

    notify:
      - Restart nomad

  handlers:
  - name: Restart nomad
    ansible.builtin.service:
      name: nomad
      state: restarted

  - name: Restart consul
    ansible.builtin.service:
      name: consul
      state: restarted

  - name: Restart traefik
    ansible.builtin.service:
      name: traefik
      state: restarted

EOF

cat >Vagrantfile<<EOF
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define "potbuilder", primary: false do |node|
    node.vm.hostname = 'potbuilder'
    node.vm.box = "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"
    node.vm.synced_folder '.', '/vagrant', disabled: true
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = "2"
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["setextradata", :id,
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = 'virtio'
    end
  end

  config.vm.define "minipot", primary: true do |node|
    node.vm.hostname = 'minipot'
    node.vm.box = "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"
    node.vm.synced_folder '.', '/vagrant', disabled: true
    node.disksize.size = '32GB'
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = "2"
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["setextradata", :id,
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = 'virtio'
    end
    node.vm.network :private_network, ip: "${NETWORK}.3"
    node.vm.network :forwarded_port, guest: 4646, host_ip: "${NETWORK}.1",
      host: 4646, id: "nomad"
    node.vm.network :forwarded_port, guest: 8080, host_ip: "${NETWORK}.1",
      host: 8080, id: "www"
    node.vm.network :forwarded_port, guest: 8500, host_ip: "${NETWORK}.1",
      host: 8500, id: "consul"
    node.vm.network :forwarded_port, guest: 9002, host_ip: "${NETWORK}.1",
      host: 9002, id: "traefik"
  end

  config.vm.define "pottery", primary: false do |node|
    node.vm.hostname = 'pottery'
    node.vm.box = "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"
    node.vm.synced_folder '.', '/vagrant', disabled: true
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = "1"
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["setextradata", :id,
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = 'virtio'
    end

    node.vm.network :private_network, ip: "${NETWORK}.2"
    node.vm.network :forwarded_port, guest: 80, host_ip: "${NETWORK}.1", host: 10180, id: "www"
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
EOF

cat >potman.ini<<EOF
[kiln]
name="$KILN_NAME"
vm_manager="vagrant"
freebsd_version="${FREEBSD_VERSION}"
network="${NETWORK}"
flavours_dir="${FLAVOURS_DIR}"
EOF

cat >.gitignore<<EOF
*~
.vagrant
_build
EOF

step "Success"

echo "Created kiln $KILN_NAME"
