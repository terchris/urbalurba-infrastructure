# File: platforms/aks/tofu/main.tf
#
# Step 1: Resource Group + AKS cluster only.
# Matches the az aks create flags from the original hosts/azure-aks/01-azure-aks-create.sh
# ACR, Key Vault, networking modules come in later steps.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

# ─── Local values ─────────────────────────────────────────────────────────────
locals {
  tags = {
    CostCenter    = var.tag_cost_center
    Project       = var.tag_project
    Environment   = var.tag_environment
    BusinessOwner = var.tag_business_owner
    ITOwner       = var.tag_it_owner
    ManagedBy     = "opentofu"
    Platform      = "aks"
  }
}

# ─── Resource Group ───────────────────────────────────────────────────────────
resource "azurerm_resource_group" "aks" {
  name     = var.resource_group
  location = var.location
  tags     = local.tags
}

# ─── Log Analytics Workspace (required for monitoring addon) ──────────────────
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "law-${var.cluster_name}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# ─── AKS Cluster ──────────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.cluster_name
  tags                = local.tags

  # Matches: --enable-managed-identity
  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name            = "default"
    node_count      = var.node_count
    vm_size         = var.node_size
    os_disk_size_gb = var.os_disk_size_gb

    # Matches: --enable-cluster-autoscaler --min-count --max-count
    auto_scaling_enabled = true
    min_count            = var.min_count
    max_count            = var.max_count
  }

  # Matches: --network-plugin azure --network-policy azure
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  # Matches: --enable-addons monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  # Matches: --tier free
  sku_tier = "Free"
}
