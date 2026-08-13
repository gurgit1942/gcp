##############################################################################
# Sample values - replace with your own before applying.
##############################################################################

project_id   = "my-gcp-project"
region       = "us-central1"
zone         = "us-central1-a"
zone_passive = "us-central1-b"
name_prefix  = "pan"

# ---- Networks (one VPC per interface) --------------------------------------
outside_vpc = {
  create      = true
  vpc_name    = "pan-outside-vpc"
  subnet_name = "pan-outside-subnet"
  cidr        = "10.10.0.0/24"
}

inside_vpc = {
  create      = true
  vpc_name    = "pan-inside-vpc"
  subnet_name = "pan-inside-subnet"
  cidr        = "10.10.1.0/24"
}

mgmt_vpc = {
  create      = true
  vpc_name    = "pan-mgmt-vpc"
  subnet_name = "pan-mgmt-subnet"
  cidr        = "10.10.2.0/24"
}

ha_vpc = {
  create      = true
  vpc_name    = "pan-ha-vpc"
  subnet_name = "pan-ha-subnet"
  cidr        = "10.10.3.0/24"
}

# Lock this down to your admin/jump-host ranges in production.
mgmt_allowed_cidrs    = ["203.0.113.0/24"]
assign_mgmt_public_ip = true

# ---- Static internal IPs (must sit inside the matching subnet CIDR) --------
active_ips = {
  outside = "10.10.0.10"
  inside  = "10.10.1.10"
  mgmt    = "10.10.2.10"
  ha      = "10.10.3.10"
}

passive_ips = {
  outside = "10.10.0.11"
  inside  = "10.10.1.11"
  mgmt    = "10.10.2.11"
  ha      = "10.10.3.11"
}

# ---- Instance --------------------------------------------------------------
machine_type      = "n2-standard-4"
boot_disk_size_gb = 60

image = {
  project = "paloaltonetworksgcp-public"
  family  = "vmseries-flex-bundle1-1114"
}

# admin:<your-openssh-public-key>
ssh_public_key = "admin:ssh-rsa AAAAB3NzaC1yc2EXAMPLEEXAMPLE... admin@example.com"

# ---- Bootstrap / HA --------------------------------------------------------
bootstrap_bucket    = ""    # e.g. "my-pan-bootstrap-bucket"
mgmt_interface_swap = false # nic0 is management, so no swap needed

# Leave empty to let Terraform create a dedicated failover service account.
service_account_email = ""

extra_metadata = {}
