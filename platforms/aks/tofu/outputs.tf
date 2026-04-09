# File: platforms/aks/tofu/outputs.tf

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group" {
  description = "Resource group containing the cluster"
  value       = azurerm_resource_group.aks.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.aks.location
}

output "kube_config_raw" {
  description = "Raw kubeconfig — written to file by 01-apply.sh"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "cluster_identity_principal_id" {
  description = "Principal ID of the cluster's managed identity — needed for ACR/KV role assignments in later steps"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "node_resource_group" {
  description = "Auto-created resource group containing node VMs"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}
