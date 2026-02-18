#!/bin/bash
set -e

if [ -z "$SSH_PUBLIC_KEY" ]; then
    echo "Error: no env SSH_PUBLIC_KEY"
    exit 1
fi

lxc profile create base-infra 2>/dev/null || true
cat << EOF | lxc profile edit base-infra
config:
  cloud-init.user-data: |
    #cloud-config
    ssh_pwauth: no
    users:
      - name: admin
        groups: sudo
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${SSH_PUBLIC_KEY}

    package_update: true
    package_upgrade: true

    packages:
      - curl
      - wget
      - python3
      - openssh-server

    runcmd:
      - systemctl enable ssh
      - timedatectl set-timezone Europe/Kaliningrad

description: Base profile
devices:
  eth0:
    name: eth0
    network: lxdbr0
    type: nic
  root:
    path: /
    pool: default
    type: disk
EOF

declare -A vms=( ["app01"]="4096MB" ["mon01"]="4096MB" ["prom01"]="2048MB" )
for vm in "${!vms[@]}"; do
    echo "Starting: $vm (${vms[$vm]})"
    lxc launch ubuntu:24.04 ${vm} --vm --profile base-infra
    sleep 10
    echo "$vm Ready. IP: $(lxc list ${vm} -c 4 --format csv)"
done
echo "All VMs are running..."
