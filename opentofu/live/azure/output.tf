output "azure_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "cribl_app_id" {
  value = azuread_application_registration.cribl.client_id
}

output "cribl_app_secret" {
  value     = azuread_application_password.cribl_secret.value
  sensitive = true
}

output "cribl_ingestion_url" {
  value = azurerm_monitor_data_collection_endpoint.cribl_dce.logs_ingestion_endpoint
}

output "arc_onboarding_id" {
  value = azuread_application_registration.arc_onboard.client_id
}

output "arc_onboarding_secret" {
  value     = azuread_service_principal_password.arc_onboard_secret.value
  sensitive = true
}
