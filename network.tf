##############################################################################
# VPCs + subnets - one per firewall interface.
# Each block is created only when <net>.create = true; otherwise the existing
# VPC/subnet of the given name is looked up and reused.
##############################################################################

locals {
  networks = {
    outside = var.outside_vpc
    inside  = var.inside_vpc
    mgmt    = var.mgmt_vpc
    ha      = var.ha_vpc
  }

  networks_to_create = { for k, v in local.networks : k => v if v.create }
  networks_existing  = { for k, v in local.networks : k => v if !v.create }
}

# ---- Created networks ------------------------------------------------------

resource "google_compute_network" "this" {
  for_each = local.networks_to_create

  name                    = each.value.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  for_each = local.networks_to_create

  name          = each.value.subnet_name
  ip_cidr_range = each.value.cidr
  region        = var.region
  network       = google_compute_network.this[each.key].id
}

# ---- Existing networks (data lookups) --------------------------------------

data "google_compute_network" "existing" {
  for_each = local.networks_existing
  name     = each.value.vpc_name
}

data "google_compute_subnetwork" "existing" {
  for_each = local.networks_existing
  name     = each.value.subnet_name
  region   = var.region
}

# ---- Unified references used by the instances ------------------------------

locals {
  network_ids = {
    for k, v in local.networks :
    k => v.create ? google_compute_network.this[k].id : data.google_compute_network.existing[k].id
  }

  subnet_ids = {
    for k, v in local.networks :
    k => v.create ? google_compute_subnetwork.this[k].id : data.google_compute_subnetwork.existing[k].id
  }

  network_self_links = {
    for k, v in local.networks :
    k => v.create ? google_compute_network.this[k].self_link : data.google_compute_network.existing[k].self_link
  }
}

##############################################################################
# Firewall rules
##############################################################################

# Outside: allow inbound traffic destined to the firewall (tighten in prod).
resource "google_compute_firewall" "outside_ingress" {
  name          = "${var.name_prefix}-outside-allow-ingress"
  network       = local.network_self_links["outside"]
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "all"
  }
}

# Inside: allow all east-west traffic within the trust network.
resource "google_compute_firewall" "inside_all" {
  name          = "${var.name_prefix}-inside-allow-all"
  network       = local.network_self_links["inside"]
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "all"
  }
}

# Management: restrict to admin CIDRs (SSH + HTTPS + ping).
resource "google_compute_firewall" "mgmt_admin" {
  name          = "${var.name_prefix}-mgmt-allow-admin"
  network       = local.network_self_links["mgmt"]
  direction     = "INGRESS"
  source_ranges = var.mgmt_allowed_cidrs

  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }

  allow {
    protocol = "icmp"
  }
}

# HA: allow the two firewalls to exchange HA1/HA2 traffic within the HA subnet.
resource "google_compute_firewall" "ha_sync" {
  name          = "${var.name_prefix}-ha-allow-sync"
  network       = local.network_self_links["ha"]
  direction     = "INGRESS"
  source_ranges = [var.ha_vpc.cidr]

  allow {
    protocol = "all"
  }
}
