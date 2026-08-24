# -----------------------------------------------------------------------------
# PARADIME FORK ADDITION — one Arm node pool per Paradime env label
# (worker-arm / cronjobs-arm / theia-arm / scheduler-arm). The app charts
# select on the env label + matching taint, and all Paradime images are
# arm64-only. The upstream default pool (x86, platform charts) is deliberately
# untouched. Constraints:
# - Dps_v5 (Ampere) is the Arm series available in uksouth.
# - AKS Linux pool names: lowercase alphanumeric only, max 12 chars — the
#   hyphenated env label is invalid as a pool NAME, so the name is derived by
#   stripping hyphens and truncating; the label keeps the canonical value.
# - AKS does NOT force-add an arm64 taint (unlike GKE) — the env taint below
#   is the only taint on these nodes.
# - NAP (enable_nap) is mutually exclusive with the cluster autoscaler on
#   node pools, so under NAP these pools fall back to a fixed node_count.
# -----------------------------------------------------------------------------

locals {
  # Built-in defaults when var.node_pools_json is empty. Key = env label
  # (pool name is derived from it — see name below).
  paradime_default_node_pools = {
    "worker-arm" = {
      vm_size   = "Standard_D4ps_v6"
      disk_size = 50
      min_size  = 1
      max_size  = 4
    }
    "cronjobs-arm" = {
      vm_size   = "Standard_D2ps_v6"
      disk_size = 30 # AKS floor: os disks must be >= 30GB
      min_size  = 1
      max_size  = 3
    }
    "theia-arm" = {
      vm_size   = "Standard_D2ps_v6"
      disk_size = 50
      min_size  = 1
      max_size  = 4
    }
    "scheduler-arm" = {
      vm_size   = "Standard_D2ps_v6"
      disk_size = 75
      min_size  = 1
      max_size  = 3
    }
  }

  # JSON string because Nuon vars cannot express complex types (see
  # paradime_variables.tf). Both conditional arms must be strings — an
  # override object with omitted optional keys cannot type-unify with the
  # full default object, so decode once after selection.
  paradime_node_pools = jsondecode(
    var.node_pools_json != "" ? var.node_pools_json : jsonencode(local.paradime_default_node_pools)
  )
}

# One node pool per env label. Every optional key falls back to a sane
# default so an override entry can be as small as {}.
resource "azurerm_kubernetes_cluster_node_pool" "paradime" {
  for_each = local.paradime_node_pools

  # Pool NAME rules (Linux): lowercase alphanumeric only, max 12 chars.
  # worker-arm→workerarm, cronjobs-arm→cronjobsarm, theia-arm→theiaarm,
  # scheduler-arm→schedulerarm. The env label/taint keep the hyphenated key.
  name                  = substr(replace(each.key, "-", ""), 0, 12)
  kubernetes_cluster_id = module.aks.aks_id
  mode                  = "User"

  vm_size         = try(each.value.vm_size, "Standard_D2ps_v6")
  os_disk_size_gb = try(each.value.disk_size, 50)
  os_sku          = try(each.value.os_sku, "Ubuntu") # matches upstream default pool
  vnet_subnet_id  = data.azurerm_subnet.existing.id

  # Single zone by default; a per-pool zones key overrides for multi-zone.
  # Zone 3, not 1: Arm v6 capacity in uksouth is subscription-restricted to
  # zone 3 on the paradime-byoc subscription (zones 1,2 report
  # NotAvailableForSubscription). Re-check per subscription/region.
  zones = try(each.value.zones, ["3"])

  # NAP is mutually exclusive with the cluster autoscaler on node pools:
  # under enable_nap these pools run at a fixed node_count instead.
  auto_scaling_enabled = var.enable_nap ? false : true
  min_count            = var.enable_nap ? null : try(each.value.min_size, 1)
  max_count            = var.enable_nap ? null : try(each.value.max_size, 4)
  node_count           = var.enable_nap ? try(each.value.min_size, 1) : null

  # The env label is what the app charts' node affinities select on.
  node_labels = { env = each.key }

  # Paired with the env label above: only workloads selecting the label and
  # tolerating the taint land here. AKS adds no arm64 taint of its own.
  node_taints = ["env=${each.key}:NoSchedule"]

  lifecycle {
    # With autoscaling enabled the autoscaler owns the live count.
    ignore_changes = [node_count]
  }
}
