module "aks" {
  source  = "Azure/aks/azurerm//v4"
  version = "~> 10.1.0"

  identity_type = "SystemAssigned"

  location                  = var.location
  prefix                    = var.nuon_id
  resource_group_name       = data.azurerm_resource_group.rg.name
  kubernetes_version        = var.cluster_version
  automatic_channel_upgrade = "patch"
  # System pool pinned to the SKU/zone with granted quota AND real capacity on
  # the paradime-byoc subscription (D*s_v3/v5 preflight-fail on capacity in
  # uksouth; Dlds_v6 is zone-3-only).
  agents_size               = var.system_vm_size
  agents_availability_zones = var.system_pool_zones
  agents_count              = var.enable_nap ? 1 : null
  agents_max_count          = var.enable_nap ? null : 1
  agents_max_pods           = 100
  agents_min_count          = var.enable_nap ? null : 1
  agents_pool_max_surge     = 1
  agents_pool_name          = "agents"
  agents_pool_linux_os_configs = [
    {
      transparent_huge_page_enabled = "always"
      sysctl_configs = [
        {
          fs_aio_max_nr               = 65536
          fs_file_max                 = 100000
          fs_inotify_max_user_watches = 1000000
        }
      ]
    }
  ]
  agents_type            = "VirtualMachineScaleSets"
  azure_policy_enabled   = true
  enable_auto_scaling    = var.enable_nap ? false : true
  enable_host_encryption = false

  key_vault_secrets_provider_enabled = true
  local_account_disabled             = true
  log_analytics_workspace_enabled    = false
  net_profile_dns_service_ip         = local.dns_service_ip
  net_profile_service_cidr           = local.service_cidr
  network_plugin                     = "azure"
  network_plugin_mode                = var.enable_nap ? "overlay" : null
  network_policy                     = var.enable_nap ? "cilium" : "azure"
  ebpf_data_plane                    = var.enable_nap ? "cilium" : null
  os_disk_size_gb                    = 60
  oidc_issuer_enabled                = true
  private_cluster_enabled            = lower(var.cluster_endpoint_public_access) == "false"
  role_based_access_control_enabled  = true
  rbac_aad                           = true
  rbac_aad_azure_rbac_enabled        = true
  rbac_aad_tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_tier                           = "Standard"
  vnet_subnet                        = { id = data.azurerm_subnet.existing.id }
  attached_acr_id_map = {
    "${azurerm_container_registry.acr.name}" = azurerm_container_registry.acr.id
  }

  # No extra x86 user pool: minimal-x86 topology — AKS system pods live on the
  # "agents" system pool, platform charts on the tainted platform-arm pool,
  # app workloads on the env-tainted Arm pools. The module's create_before_
  # destroy naming rotated this pool on EVERY apply, and its temp pool always
  # lands in the (IP-exhausted) default subnet — dropping the pool removes the
  # churn and the last non-system x86 spend.
  node_pools = {}

  workload_identity_enabled = true
}
