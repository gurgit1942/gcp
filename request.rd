create terraform script for gcp palo alto firewall in active passive configuration.
It has four nic cards.
Nic0 will be in management vpc 
Nic1 will be in outside vpc
nic2 will be in inside vpc
nic3 will be in ha vpc
HA pairing is via ha vpc.
Assume VPC and subnets are already created.
IP assigments are set to auto.
Nic1 will be assigned a public IP address.
create tfvars file with sample values also
