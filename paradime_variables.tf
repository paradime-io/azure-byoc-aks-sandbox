# -----------------------------------------------------------------------------
# PARADIME FORK ADDITION — do not edit upstream variables.tf.
# Nuon vars cannot express complex types, so complex inputs arrive as
# JSON-encoded strings and are jsondecode()d in-module (same node_pools_json
# pattern as the AWS/GCP sibling forks — keep the three in sync).
# -----------------------------------------------------------------------------

variable "node_pools_json" {
  type        = string
  default     = ""
  description = "JSON object of Paradime env node pools keyed by env label (pool name is the label with hyphens stripped, truncated to 12 chars — AKS Linux pool names are lowercase alphanumeric, max 12). Each entry: {vm_size, disk_size, min_size, max_size} plus optional os_sku / zones. Azure has no 1-vCPU Dps size; Standard_D2ps is the floor (v6 in uksouth — no v5 Arm there). Empty string means use the built-in Paradime defaults in paradime_pools.tf. Passed as a string because Nuon [vars] cannot express complex types."

  validation {
    condition     = var.node_pools_json == "" || can(jsondecode(var.node_pools_json))
    error_message = "node_pools_json must be empty or a valid JSON object."
  }
}
