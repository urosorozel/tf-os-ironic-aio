provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "openstack_aio_pool" {
  name = var.storage_pool_name
  type = "dir"
  path = "${var.storage_pool}/${var.storage_pool_name}"

}

# Define locals for destory
locals {
    ironic_prefix = var.ironic_node_prefix
}

resource "libvirt_network" "openstack_aio_network" {
  name      = "aio-network"
  bridge    = "aio-network"
  mtu       = 1500
  mode      = "nat"
  domain    = "${var.domain_name}"
  addresses = [var.openstack_aio_network]
  dhcp {
	enabled = true
  }
  dns {
    enabled = true
    local_only = true
  }
#  provisioner "local-exec" {
#    command = "virsh net-update --network aio-network delete ip-dhcp-range '<range start='10.240.0.2' end='10.240.3.254'/>'  --live --config
#               virsh net-update --network aio-network add ip-dhcp-range '<range start='10.240.0.2' end='10.240.0.50'/>'  --live --config"
#  }
}

resource "libvirt_network" "openstack_aio_ironic_network" {
  name      = "aio-ironic"
  mode      = "nat"
  bridge    = "aio-ironic"
  addresses = [var.openstack_aio_ironic_network]
  dhcp {
        enabled = false
  }
  dns {
    enabled = false
    local_only = true
  }
  #routes {
  #    cidr = "10.240.0.0/22"
  #    gateway = "10.240.0.1"
  #}
}


data "template_file" "aio_user_data" {
  template = "${file("${path.module}/cloudinit/cloud_init.yml")}"

  vars = {
    user_name          = "ubuntu"
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}

data "template_file" "aio_meta_data" {
  count    = "${var.aio_node_count}"
  template = "${file("${path.module}/cloudinit/meta_data.yml")}"

  vars = {
    hostname = "${format("${var.aio_node_prefix}-%02d", count.index + 1)}"
  }
}

data "template_file" "aio_network_config" {
  count    = "${var.aio_node_count}"
  template = "${file("${path.module}/cloudinit/network_config.yml")}"

  vars = {
    br_mgmt = cidrhost(var.aio_node_vlan.br_mgmt, count.index + 1 + var.aio_node_vlan.ip_offset)
    br_ovs = cidrhost(var.aio_node_vlan.br_ovs, count.index + 1 + var.aio_node_vlan.ip_offset)
    br_storage = cidrhost(var.aio_node_vlan.br_storage, count.index + 1 + var.aio_node_vlan.ip_offset)
    br_pxe = cidrhost(var.aio_node_vlan.br_pxe, count.index + 1 + var.aio_node_vlan.ip_offset)
  }
}

resource "libvirt_cloudinit_disk" "aio_commoninit" {
  count          = "${var.aio_node_count}"
  name           = "${format("${var.aio_node_prefix}-seed-%01d.iso", count.index + 1)}"
  pool           = libvirt_pool.openstack_aio_pool.name
  user_data      = "${data.template_file.aio_user_data.rendered}"
  meta_data      = "${data.template_file.aio_meta_data.*.rendered[count.index]}"
  network_config = "${data.template_file.aio_network_config.*.rendered[count.index]}"
}

resource "libvirt_volume" "ubuntu-image" {
  name = "${var.qcow_image_filename}"
  pool = libvirt_pool.openstack_aio_pool.name
  source = "${var.qcow_image_path}/${var.qcow_image_filename}"
  format = "qcow2"
  depends_on = [libvirt_pool.openstack_aio_pool]
}

resource "libvirt_volume" "master-deploy-image" {
  name = "${var.aio_node_prefix}-${count.index}.qcow2"
  base_volume_id = libvirt_volume.ubuntu-image.id
  pool = libvirt_pool.openstack_aio_pool.name
  size = "${var.aio_node_disk}" 
  format = "qcow2"
  count = "${var.aio_node_count}"
  depends_on = [libvirt_pool.openstack_aio_pool]
}

# Volume

# Define KVM domain to create
resource "libvirt_domain" "aio_nodes" {
  name   = "${format("${var.aio_node_prefix}-%02d", count.index + 1)}"
  memory = "${var.aio_node_memory}"
  vcpu   = "${var.aio_node_cpu}"

  network_interface {
    network_name = libvirt_network.openstack_aio_network.name
    #addresses = ["10.200.0.100"]
    wait_for_lease = false
  }
  network_interface {
    network_name = libvirt_network.openstack_aio_ironic_network.name
    wait_for_lease = false
  }
  disk {
    volume_id = "${element(libvirt_volume.master-deploy-image,count.index).id}"
  }

  cloudinit = "${element(libvirt_cloudinit_disk.aio_commoninit,count.index).id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
      type        = "pty"
      target_type = "virtio"
      target_port = "1"
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    #listen_address = "10.184.227.238"
    autoport = true
  }
  count = "${var.aio_node_count}"
}

# END AIO NODE

resource "libvirt_volume" "ironic-deploy-image" {
  name = "${var.ironic_node_prefix}-${count.index}.qcow2"
  pool = libvirt_pool.openstack_aio_pool.name
  size = "${var.ironic_node_disk}"
  format = "qcow2"
  count = "${var.ironic_node_count}"
  depends_on = [libvirt_pool.openstack_aio_pool]
}

resource "libvirt_domain" "ironic_nodes" {
  name   = "${format("${var.ironic_node_prefix}-%02d", count.index + 1)}"
  memory = "${var.ironic_node_memory}"
  vcpu   = "${var.ironic_node_cpu}"
  #firmware = "/usr/share/OVMF/OVMF_CODE.fd"
  network_interface {
    network_name = libvirt_network.openstack_aio_ironic_network.name
    mac = "${format("52:54:00:fa:fa:%02d", count.index + 1)}"
    wait_for_lease = false
  }
  disk {
    volume_id = "${element(libvirt_volume.ironic-deploy-image,count.index).id}"
  }

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
      type        = "pty"
      target_type = "virtio"
      target_port = "1"
  }

  boot_device {
    dev = ["hd", "network"]
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    #listen_address = "10.184.227.238"
    autoport = true
  }
  count = "${var.ironic_node_count}"
  depends_on = [libvirt_pool.openstack_aio_pool,libvirt_network.openstack_aio_ironic_network,libvirt_volume.ironic-deploy-image]
}

# END IRONIC

resource "null_resource" "add-address" {
   provisioner "local-exec" {
       command = "sudo ip addr add ${cidrhost(var.openstack_aio_network, count.index + var.openstack_aio_vbmc_offset)}/32 dev aio-network"
   }
   count = "${var.ironic_node_count}"
   depends_on = [libvirt_network.openstack_aio_network]
}

resource "null_resource" "add-vbmc-host" {
   provisioner "local-exec" {
       interpreter = ["/bin/bash", "-c"]
       command = <<-EOT
           /opt/vbmc/bin/vbmc add --username admin --password admin --address ${cidrhost(var.openstack_aio_network, count.index + var.openstack_aio_vbmc_offset)} ${format("${var.ironic_node_prefix}-%02d", count.index + 1)}
           /opt/vbmc/bin/vbmc start ${format("${var.ironic_node_prefix}-%02d", count.index + 1)}
           EOT
   }
   count = "${var.ironic_node_count}"
   depends_on = [null_resource.add-address,libvirt_domain.ironic_nodes]
}

resource "null_resource" "del-vbmc-host" {
   provisioner "local-exec" {
       when = destroy
       command = "/opt/vbmc/bin/vbmc list -f value -c 'Domain name' | xargs /opt/vbmc/bin/vbmc delete"
   }
}


resource "ansible_host" "aio_nodes" {
    inventory_hostname = "${format("${var.aio_node_prefix}-%02d", count.index + 1)}.${var.domain_name}"
    groups = ["openstack-cluster","aio"]
    vars = {
        ansible_user = "ubuntu"
        ansible_host = "${format("${var.aio_node_prefix}-%02d", count.index + 1)}.${var.domain_name}"
    }
    count = "${var.aio_node_count}"
    depends_on = [libvirt_domain.aio_nodes]
}

resource "ansible_host" "aio_ironic" {
    inventory_hostname = "${format("${var.ironic_node_prefix}-%02d", count.index + 1)}.${var.domain_name}"
    groups = ["openstack-cluster","aio"]
    vars = {
        ansible_user = "ubuntu"
        ansible_host = "${format("${var.ironic_node_prefix}-%02d", count.index + 1)}.${var.domain_name}"
    }
    count = "${var.ironic_node_count}"
    depends_on = [libvirt_domain.ironic_nodes]
}

output "aio_ips" {
  value = libvirt_domain.aio_nodes.*.network_interface.0.addresses
}
