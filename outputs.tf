output "vnet" {
  value = {
    id         = data.azurerm_virtual_network.existing.id
    name       = data.azurerm_virtual_network.existing.name
    subnet_ids = [data.azurerm_subnet.existing.id]
    # Paradime fork: subnets the platform module consumes (paradime_subnets.tf).
    db_subnet_id               = azurerm_subnet.paradime_db.id
    private_endpoint_subnet_id = azurerm_subnet.paradime_private_endpoints.id
  }
  description = "A map of vnet attributes: name, subnet_ids."
}


output "public_domain" {
  value = {
    nameservers = azurerm_dns_zone.public.name_servers
    name        = azurerm_dns_zone.public.name
    id          = azurerm_dns_zone.public.id
  }
  description = "A map of public domain attributes: nameservers, name, id."
}

output "internal_domain" {
  value = {
    nameservers = []
    name        = azurerm_private_dns_zone.internal.name
    id          = azurerm_private_dns_zone.internal.id
  }
  description = "A map of internal domain attributes: nameservers, name, id."
}

output "nuon_dns" {
  value = {
    enabled = true
    public_domain = {
      zone_id     = azurerm_dns_zone.public.id
      name        = azurerm_dns_zone.public.name
      nameservers = tolist(azurerm_dns_zone.public.name_servers)
    }
    internal_domain = {
      zone_id     = azurerm_private_dns_zone.internal.id
      name        = azurerm_private_dns_zone.internal.name
      nameservers = tolist([])
    }
    alb_ingress_controller = {
      enabled  = false
      id       = ""
      chart    = ""
      revision = ""
    }
    external_dns = {
      enabled  = false
      id       = ""
      chart    = ""
      revision = ""
    }
    cert_manager = {
      enabled  = false
      id       = ""
      chart    = ""
      revision = ""
    }
    ingress_nginx = {
      enabled  = false
      id       = ""
      chart    = ""
      revision = ""
    }
  }
  description = "A map of Nuon DNS attributes matching the structure expected by ctl-api ProvisionDNS workflow for Route53 NS delegation."
}

output "account" {
  value = {
    "location"            = var.location
    "subscription_id"     = data.azurerm_client_config.current.subscription_id
    "client_id"           = data.azurerm_client_config.current.client_id
    "resource_group_name" = data.azurerm_resource_group.rg.name
  }
  description = "A map of Azure account attributes: location, subscription_id, client_id, resource_group_name."
}

output "acr" {
  value = {
    id           = azurerm_container_registry.acr.id
    name         = azurerm_container_registry.acr.name
    login_server = azurerm_container_registry.acr.login_server
  }
  description = "A map of ACR attributes: id, login_server."
}

output "cluster" {
  value = {
    "id"                     = module.aks.aks_id
    "name"                   = module.aks.aks_name
    "version"                = var.cluster_version
    "client_certificate"     = nonsensitive(module.aks.client_certificate)
    "client_key"             = nonsensitive(module.aks.client_key)
    "cluster_ca_certificate" = nonsensitive(module.aks.cluster_ca_certificate)
    "cluster_fqdn"           = module.aks.cluster_fqdn
    "oidc_issuer_url"        = module.aks.oidc_issuer_url
    "location"               = module.aks.location
    "kube_config_raw"        = nonsensitive(module.aks.kube_config_raw)
    "kube_admin_config_raw"  = nonsensitive(module.aks.kube_admin_config_raw)
    host                     = nonsensitive(module.aks.host)
  }
  description = "A map of AKS cluster attributes: id, name, client_certificate, client_key, cluster_ca_certificate, cluster_fqdn, oidc_issuer_url, location, kube_config_raw, kube_admin_config_raw."
}
