# File: platforms/aks/tofu/variables.tf

# ─── Azure Identity ────────────────────────────────────────────────────────────
variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

# ─── Resource Group ───────────────────────────────────────────────────────────
variable "resource_group" {
  description = "Resource group name for the AKS cluster"
  type        = string
  default     = "rg-urbalurba-aks-weu"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

# ─── AKS Cluster ──────────────────────────────────────────────────────────────
variable "cluster_name" {
  description = "AKS cluster name (also used as kubectl context name)"
  type        = string
  default     = "azure-aks"
}

variable "node_count" {
  description = "Initial node count"
  type        = number
  default     = 1
}

variable "node_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_B2ms"
}

variable "min_count" {
  description = "Minimum node count for autoscaler"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum node count for autoscaler"
  type        = number
  default     = 3
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

# ─── Tags ─────────────────────────────────────────────────────────────────────
variable "tag_cost_center" {
  description = "Cost center tag"
  type        = string
}

variable "tag_project" {
  description = "Project tag"
  type        = string
  default     = "urbalurba-infrastructure"
}

variable "tag_environment" {
  description = "Environment tag"
  type        = string
  default     = "Production"
}

variable "tag_business_owner" {
  description = "Business owner email tag"
  type        = string
}

variable "tag_it_owner" {
  description = "IT owner email tag"
  type        = string
}
