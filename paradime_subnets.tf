# PARADIME FORK ADDITION — subnets the platform module requires but the Nuon
# ARM vnet does not create: a Postgres-delegated subnet (a delegated subnet
# cannot host private endpoints) and a private-endpoint subnet.
#
# CIDRs default to /24s carved from the vnet's first address space, chosen
# above the ARM template's highest default allocation (10.128.134.0/24 when
# vnetCIDR is a /16). Override both if the install's vnetCIDR was customised.

variable "paradime_db_subnet_cidr" {
  type        = string
  default     = ""
  description = "CIDR for the Postgres-delegated subnet. Empty derives netnum 136 (/24 within a /16) from the vnet address space."
}

variable "paradime_pe_subnet_cidr" {
  type        = string
  default     = ""
  description = "CIDR for the private-endpoint subnet. Empty derives netnum 137 (/24 within a /16) from the vnet address space."
}

locals {
  vnet_space              = data.azurerm_virtual_network.existing.address_space[0]
  paradime_subnet_newbits = 24 - tonumber(split("/", local.vnet_space)[1])
  paradime_db_cidr        = var.paradime_db_subnet_cidr != "" ? var.paradime_db_subnet_cidr : cidrsubnet(local.vnet_space, local.paradime_subnet_newbits, 136)
  paradime_pe_cidr        = var.paradime_pe_subnet_cidr != "" ? var.paradime_pe_subnet_cidr : cidrsubnet(local.vnet_space, local.paradime_subnet_newbits, 137)
}

resource "azurerm_subnet" "paradime_db" {
  name                 = "paradime-db"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.existing.name
  address_prefixes     = [local.paradime_db_cidr]

  delegation {
    name = "postgres-flexible"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "paradime_private_endpoints" {
  name                 = "paradime-private-endpoints"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.existing.name
  address_prefixes     = [local.paradime_pe_cidr]
}

output "db_subnet_id" {
  value       = azurerm_subnet.paradime_db.id
  description = "Postgres-delegated subnet for the platform module's Flexible Server."
}

output "private_endpoint_subnet_id" {
  value       = azurerm_subnet.paradime_private_endpoints.id
  description = "Subnet for the platform module's private endpoints (Redis, Files, Blob)."
}

# Second private subnet for IP-hungry additions: Azure CNI pre-allocates
# max_pods+1 IPs per node, and the upstream sandbox pins every pool into
# private subnet [0] (a /24 = 251 IPs) — near-full with the app pools.
data "azurerm_subnet" "paradime_private_2" {
  name                 = local.private_subnet_name_list[1]
  virtual_network_name = data.azurerm_virtual_network.existing.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}
