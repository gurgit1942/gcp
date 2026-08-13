# GCP Palo Alto VM-Series — Active/Passive HA

Terraform for a pair of Palo Alto Networks VM-Series firewalls on GCP in an
active/passive HA topology.

## Topology

Two VM-Series instances (active + passive), each in a different zone of the same
region, each with **four** network interfaces:

| NIC  | VPC          | Role                                   |
|------|--------------|----------------------------------------|
| nic0 | management   | PAN-OS management plane (mgmt IP)      |
| nic1 | outside VPC  | Untrust / public (public IP attached)  |
| nic2 | inside VPC   | Trust / private                        |
| nic3 | ha VPC       | HA1 control + HA2 data-sync link       |

> Your request listed three dataplane NICs (outside/inside/mgmt) plus an HA VPC.
> Active/passive HA needs its own link, so the HA VPC is wired as a **4th NIC**
> (nic3). Four NICs require a machine type with ≥ 4 vCPUs (`n2-standard-4`).

## GCP-specific HA notes

- **No gratuitous ARP.** On GCP, PAN-OS failover moves traffic by calling the
  GCP API to relocate routes/alias IPs to the newly-active firewall. The
  instances therefore run with a service account (created by this module unless
  you supply `service_account_email`) that has `roles/compute.instanceAdmin.v1`.
  Complete the floating-IP / route-failover configuration inside PAN-OS.
- **nic0 is management.** GCP puts the default route on nic0 and PAN-OS treats
  it as the management interface by default, which matches this layout — so
  `mgmt_interface_swap` is left **disabled**. (Set it to `true` only if you ever
  move the dataplane onto nic0.)
- **can_ip_forward** is enabled so the firewalls can forward transit traffic.

## Usage

```bash
cd gcp-palo-ha
# edit terraform.tfvars with your project, CIDRs, IPs, image and SSH key
terraform init
terraform plan
terraform apply
```

## Files

- `providers.tf` — provider + version pins
- `variables.tf` — all inputs (networks support create-or-reuse)
- `network.tf` — VPCs, subnets, firewall rules
- `firewall.tf` — static IPs, service account, the two VM-Series instances
- `outputs.tf` — instance IPs and service account
- `terraform.tfvars` — sample values

## Before production

- Restrict `mgmt_allowed_cidrs` and the outside ingress rule.
- Point `image.family` at the VM-Series version/license bundle you intend to run
  and accept the marketplace terms for it in your project.
- Populate `bootstrap_bucket` with a bootstrap package (`config/`, `content/`,
  `license/`, `software/`) so the firewalls come up configured for HA.
