provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "k8s_disk" {
  count  = 4
  name   = "k8s_disk_${count.index}"
  pool   = "default"
  source = "https://cdimage.debian.org/cdimage/openstack/current-10/debian-10-openstack-amd64.qcow2"
  format = "qcow2"
}

resource "libvirt_domain" "k8s_node" {
  count = 4
  name  = "k8s_node_${count.index}"
  memory = 2048
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.common-init.id

  network_interface {
    network_name = "default"
  }

  disk {
    volume_id = libvirt_volume.k8s_disk[count.index].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

resource "libvirt_cloudinit_disk" "common-init" {
  name = "common-init.iso"
  pool = "default"

  user_data = <<-EOF
  #cloud-config
  users:
    - default
    - name: debian
      sudo: ALL=(ALL) NOPASSWD:ALL
      groups: users, admin
      home: /home/debian
      shell: /bin/bash
      lock_passwd: false
      plain_text_passwd: 'debian'
  package_update: true
  packages:
    - qemu-guest-agent
    - docker.io
  runcmd:
    - systemctl start docker
    - systemctl enable docker
    - curl -sfL https://get.k3s.io | sh -
    - sudo cp /etc/rancher/k3s/k3s.yaml /home/debian/.kube/config
    - sudo chown debian:debian /home/debian/.kube/config
  EOF
}

output "libvirt_domain_ips" {
  value = libvirt_domain.k8s_node[*].network_interface.0.addresses
}
