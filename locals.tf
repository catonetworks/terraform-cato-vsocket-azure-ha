locals {
  lan_first_ip = cidrhost(var.subnet_range_lan, 1)
}