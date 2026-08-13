output "active_firewall" {
  description = "Active firewall details."
  value = {
    name        = google_compute_instance.fw["active"].name
    zone        = google_compute_instance.fw["active"].zone
    outside_ip  = var.active_ips.outside
    inside_ip   = var.active_ips.inside
    mgmt_ip     = var.active_ips.mgmt
    ha_ip       = var.active_ips.ha
    outside_pub = google_compute_instance.fw["active"].network_interface[1].access_config[0].nat_ip
    mgmt_pub    = try(google_compute_instance.fw["active"].network_interface[0].access_config[0].nat_ip, null)
  }
}

output "passive_firewall" {
  description = "Passive firewall details."
  value = {
    name        = google_compute_instance.fw["passive"].name
    zone        = google_compute_instance.fw["passive"].zone
    outside_ip  = var.passive_ips.outside
    inside_ip   = var.passive_ips.inside
    mgmt_ip     = var.passive_ips.mgmt
    ha_ip       = var.passive_ips.ha
    outside_pub = google_compute_instance.fw["passive"].network_interface[1].access_config[0].nat_ip
    mgmt_pub    = try(google_compute_instance.fw["passive"].network_interface[0].access_config[0].nat_ip, null)
  }
}

output "service_account_email" {
  description = "Service account used by the firewalls for HA API failover."
  value       = local.service_account_email
}

output "networks" {
  description = "VPC self-links per interface."
  value       = local.network_self_links
}
