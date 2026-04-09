# File: platforms/aks/tofu/backend.tf
#
# Remote state stored in Azure Blob Storage.
# The storage account is created by scripts/00-bootstrap-state.sh
#
# Values are passed via environment variables set by 01-apply.sh:
#   ARM_ACCESS_KEY - storage account key (never stored in code)
#
# Backend config cannot use variables, so the actual values are injected
# by 01-apply.sh using -backend-config flags at tofu init time.

terraform {
  backend "azurerm" {
    # Values injected at init time via -backend-config flags in 01-apply.sh
    # See azure-aks-config.sh for the actual values
  }
}
