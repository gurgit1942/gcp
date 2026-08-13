##############################################################################
# Service account for HA failover.
#
# In GCP, PAN-OS active/passive HA does not use gratuitous ARP. On failover the
# newly-active firewall calls the GCP API to move the outside/inside routes (or
# alias/floating IPs) to itself. That requires a service account with rights to
# edit routes and instances.
##############################################################################

resource "google_service_account" "fw" {
  count        = var.service_account_email == "" ? 1 : 0
  account_id   = "${var.name_prefix}-fw-ha"
  display_name = "${var.name_prefix} VM-Series HA failover"
}

resource "google_project_iam_member" "fw_compute" {
  count   = var.service_account_email == "" ? 1 : 0
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.fw[0].email}"
}

locals {
  service_account_email = var.service_account_email != "" ? var.service_account_email : google_service_account.fw[0].email

  # Bootstrap metadata common to both firewalls.
  base_metadata = merge(
    {
      "mgmt-interface-swap" = var.mgmt_interface_swap ? "enable" : "disable"
      "serial-port-enable"  = "true"
    },
    var.bootstrap_bucket != "" ? { "vmseries-bootstrap-gce-storagebucket" = var.bootstrap_bucket } : {},
    var.ssh_public_key != "" ? { "ssh-keys" = var.ssh_public_key } : {},
    var.extra_metadata,
  )
}

##############################################################################
# Static internal IPs (one per interface, per firewall)
##############################################################################

locals {
  # firewall role -> { interface -> ip }
  fw_ips = {
    active  = var.active_ips
    passive = var.passive_ips
  }

  # Flatten to "<role>-<iface>" => { role, iface, ip } for for_each addressing.
  fw_addresses = merge([
    for role, ips in local.fw_ips : {
      for iface, ip in {
        outside = ips.outside
        inside  = ips.inside
        mgmt    = ips.mgmt
        ha      = ips.ha
        } : "${role}-${iface}" => {
        role  = role
        iface = iface
        ip    = ip
      }
    }
  ]...)
}

resource "google_compute_address" "internal" {
  for_each = local.fw_addresses

  name         = "${var.name_prefix}-${each.value.role}-${each.value.iface}"
  address_type = "INTERNAL"
  address      = each.value.ip
  subnetwork   = local.subnet_ids[each.value.iface]
  region       = var.region
}

##############################################################################
# VM-Series firewalls
##############################################################################

locals {
  data_disk_image = "${var.image.project}/${var.image.family}"

  firewalls = {
    active = {
      zone = var.zone
      ips  = var.active_ips
    }
    passive = {
      zone = var.zone_passive
      ips  = var.passive_ips
    }
  }
}

resource "google_compute_instance" "fw" {
  for_each = local.firewalls

  name           = "${var.name_prefix}-fw-${each.key}"
  machine_type   = var.machine_type
  zone           = each.value.zone
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = local.data_disk_image
      size  = var.boot_disk_size_gb
      type  = "pd-ssd"
    }
  }

  # nic0 -> management (PAN-OS mgmt plane; default mgmt interface on GCP).
  network_interface {
    subnetwork = local.subnet_ids["mgmt"]
    network_ip = google_compute_address.internal["${each.key}-mgmt"].address

    dynamic "access_config" {
      for_each = var.assign_mgmt_public_ip ? [1] : []
      content {}
    }
  }

  # nic1 -> outside (untrust). Gets the public IP for north-south traffic.
  network_interface {
    subnetwork = local.subnet_ids["outside"]
    network_ip = google_compute_address.internal["${each.key}-outside"].address

    access_config {
      # Ephemeral public IP on the outside interface.
    }
  }

  # nic2 -> inside (trust).
  network_interface {
    subnetwork = local.subnet_ids["inside"]
    network_ip = google_compute_address.internal["${each.key}-inside"].address
  }

  # nic3 -> ha (HA1 control + HA2 data-sync link).
  network_interface {
    subnetwork = local.subnet_ids["ha"]
    network_ip = google_compute_address.internal["${each.key}-ha"].address
  }

  metadata = local.base_metadata

  service_account {
    email  = local.service_account_email
    scopes = ["cloud-platform"]
  }

  # VM-Series images require nested-virtualization-free host; keep defaults.
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  labels = {
    role    = each.key
    product = "vmseries"
  }
}
