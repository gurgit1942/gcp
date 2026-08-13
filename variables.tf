##############################################################################
# Project / location
##############################################################################

variable "project_id" {
  description = "GCP project ID where all resources are created."
  type        = string
}

variable "region" {
  description = "GCP region for the subnets and instances."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Primary (active) firewall zone."
  type        = string
  default     = "us-central1-a"
}

variable "zone_passive" {
  description = "Passive firewall zone. Use a different zone in the same region for zonal resilience."
  type        = string
  default     = "us-central1-b"
}

variable "name_prefix" {
  description = "Prefix prepended to every resource name."
  type        = string
  default     = "pan"
}

##############################################################################
# Networking - one VPC per firewall interface
#
# NIC order on the VM-Series (google_compute_instance network_interface blocks):
#   nic0 -> management  (PAN-OS mgmt plane; default mgmt interface on GCP)
#   nic1 -> outside     (untrust / public)
#   nic2 -> inside      (trust / private)
#   nic3 -> ha          (HA1 control + HA2 data-sync link)
##############################################################################

variable "outside_vpc" {
  description = "Outside (untrust) network. Set create=false to reuse an existing VPC/subnet by name."
  type = object({
    create      = optional(bool, true)
    vpc_name    = string
    subnet_name = string
    cidr        = string
  })
}

variable "inside_vpc" {
  description = "Inside (trust) network."
  type = object({
    create      = optional(bool, true)
    vpc_name    = string
    subnet_name = string
    cidr        = string
  })
}

variable "mgmt_vpc" {
  description = "Management network."
  type = object({
    create      = optional(bool, true)
    vpc_name    = string
    subnet_name = string
    cidr        = string
  })
}

variable "ha_vpc" {
  description = "HA pairing network (HA1/HA2 links between the active and passive firewalls)."
  type = object({
    create      = optional(bool, true)
    vpc_name    = string
    subnet_name = string
    cidr        = string
  })
}

variable "mgmt_allowed_cidrs" {
  description = "Source CIDRs permitted to reach the management interface (SSH/HTTPS)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "assign_mgmt_public_ip" {
  description = "Attach an ephemeral public IP to each firewall's management NIC (nic2)."
  type        = bool
  default     = true
}

##############################################################################
# Static internal IPs (per firewall). Must fall inside the matching subnet CIDR.
##############################################################################

variable "active_ips" {
  description = "Static internal IPs for the ACTIVE firewall, one per interface."
  type = object({
    outside = string
    inside  = string
    mgmt    = string
    ha      = string
  })
}

variable "passive_ips" {
  description = "Static internal IPs for the PASSIVE firewall, one per interface."
  type = object({
    outside = string
    inside  = string
    mgmt    = string
    ha      = string
  })
}

##############################################################################
# VM-Series instance
##############################################################################

variable "machine_type" {
  description = "Machine type. Needs >= 4 vCPUs to attach 4 NICs (GCP allows 1 NIC per vCPU)."
  type        = string
  default     = "n2-standard-4"
}

variable "image" {
  description = "VM-Series image. Reference a marketplace image family or a specific image self-link."
  type = object({
    project = string
    family  = string
  })
  default = {
    project = "paloaltonetworksgcp-public"
    family  = "vmseries-flex-bundle1-1114"
  }
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB (VM-Series requires >= 60)."
  type        = number
  default     = 60
}

variable "ssh_public_key" {
  description = "SSH public key for admin access, in 'admin:ssh-rsa AAAA...' format. Leave empty to rely on bootstrap only."
  type        = string
  default     = ""
}

##############################################################################
# Bootstrap (PAN-OS metadata). See:
# https://docs.paloaltonetworks.com/vm-series/.../bootstrap-the-vm-series-firewall-on-google
##############################################################################

variable "bootstrap_bucket" {
  description = "GCS bucket holding the bootstrap package (config/, content/, license/, software/). Empty = no bootstrap bucket."
  type        = string
  default     = ""
}

variable "mgmt_interface_swap" {
  description = "PAN-OS 'mgmt-interface-swap'. Keep disabled: nic0 is the management interface, so no swap is needed."
  type        = bool
  default     = false
}

variable "extra_metadata" {
  description = "Additional PAN-OS bootstrap metadata key/value pairs merged into every instance."
  type        = map(string)
  default     = {}
}

##############################################################################
# HA failover (API-based route/IP move performed by PAN-OS via the GCP API)
##############################################################################

variable "service_account_email" {
  description = "Service account attached to both firewalls. Empty = create a dedicated one with compute permissions for HA failover."
  type        = string
  default     = ""
}
