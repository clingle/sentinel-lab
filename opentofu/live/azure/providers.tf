provider "azurerm" {
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.GuestConfiguration",
    "Microsoft.HybridCompute",
    "Microsoft.HybridConnectivity",
    "Microsoft.ManagedIdentity",
    "Microsoft.PolicyInsights"
  ]
  features {}
}

provider "azuread" {}

provider "time" {}
