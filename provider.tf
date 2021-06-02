terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.6.1"
    }
    ansible = {
      source  = "nbering/ansible"
      version = "1.0.4"
    }
  }
}
