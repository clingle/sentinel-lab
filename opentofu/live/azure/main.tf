data "azurerm_client_config" "current" {}

data "azurerm_monitor_data_collection_rule" "cribl_dcr_default" {
  name                = azurerm_resource_group_template_deployment.cribl_dcr_default.name
  resource_group_name = azurerm_resource_group.siem.name
}

data "azurerm_monitor_data_collection_rule" "ama_linux_dcr_default" {
  name                = azurerm_resource_group_template_deployment.ama_linux_dcr_default.name
  resource_group_name = azurerm_resource_group.siem.name
}

data "azurerm_policy_set_definition" "ama_onboard_linux" {
  display_name = "Configure Linux machines to run Azure Monitor Agent and associate them to a Data Collection Rule"
}

resource "azurerm_resource_group" "siem" {
  name     = "rg-siem"
  location = "centralus"
}

resource "azurerm_log_analytics_workspace" "siem" {
  name                                    = "law-siem"
  location                                = azurerm_resource_group.siem.location
  resource_group_name                     = azurerm_resource_group.siem.name
  sku                                     = "PerGB2018"
  retention_in_days                       = 30
  daily_quota_gb                          = 9
  immediate_data_purge_on_30_days_enabled = true
}

resource "azurerm_monitor_data_collection_endpoint" "cribl_dce" {
  name                = "cribl-stream-${azurerm_resource_group.siem.location}"
  resource_group_name = azurerm_resource_group.siem.name
  location            = azurerm_resource_group.siem.location
}

resource "azurerm_resource_group_template_deployment" "cribl_dcr_default" {
  name                = "cribl-dcr-default"
  resource_group_name = azurerm_resource_group.siem.name
  deployment_mode     = "Incremental"
  template_content    = file("${path.module}/templates/cribl-dcr-default.json")

  parameters_content = jsonencode({
    "dataCollectionRuleName" = {
      "value" : "cribl-dcr-default"
    },
    "location" = {
      "value" : azurerm_resource_group.siem.location,
    },
    "workspaceResourceId" = {
      "value" : azurerm_log_analytics_workspace.siem.id
    },
    "endpointResourceId" = {
      "value" : azurerm_monitor_data_collection_endpoint.cribl_dce.id
    }
  })

  depends_on = [time_sleep.wait_for_sentinel_tables]
}

resource "time_sleep" "wait_for_sentinel_tables" {
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.siem]

  create_duration = "120s"
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "siem" {
  workspace_id                 = azurerm_log_analytics_workspace.siem.id
  customer_managed_key_enabled = false
}

resource "azuread_application_registration" "cribl" {
  display_name     = "Cribl Stream"
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_application_password" "cribl_secret" {
  application_id = azuread_application_registration.cribl.id
  end_date       = "2025-03-31T00:00:00Z"
}

resource "azuread_service_principal" "cribl" {
  client_id                    = azuread_application_registration.cribl.client_id
  app_role_assignment_required = false

  feature_tags {
    enterprise = true
  }
}

resource "azurerm_role_assignment" "cribl_metrics" {
  scope                = data.azurerm_monitor_data_collection_rule.cribl_dcr_default.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azuread_service_principal.cribl.object_id

  timeouts {
    create = "2m"
  }
}

### ARC ####
resource "azurerm_resource_group" "arc" {
  name     = "rg-arc"
  location = "centralus"
}

resource "azuread_application_registration" "arc_onboard" {
  display_name     = "Azure Arc Onboarding"
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal_password" "arc_onboard_secret" {
  service_principal_id = azuread_service_principal.arc_onboard.id
  end_date             = "2025-03-31T00:00:00Z"
}

resource "azuread_service_principal" "arc_onboard" {
  client_id                    = azuread_application_registration.arc_onboard.client_id
  app_role_assignment_required = false

  feature_tags {
    enterprise = true
  }
}

resource "azurerm_role_assignment" "arc_onboard" {
  scope                = azurerm_resource_group.arc.id
  role_definition_name = "Azure Connected Machine Onboarding"
  principal_id         = azuread_service_principal.arc_onboard.object_id
}

resource "azurerm_monitor_data_collection_endpoint" "ama_dce" {
  name                = "ama-${azurerm_resource_group.siem.location}"
  resource_group_name = azurerm_resource_group.siem.name
  location            = azurerm_resource_group.siem.location
}

resource "azurerm_resource_group_template_deployment" "ama_linux_dcr_default" {
  name                = "ama-linux-dcr-default"
  resource_group_name = azurerm_resource_group.siem.name
  deployment_mode     = "Incremental"
  template_content    = file("${path.module}/templates/ama-linux-dcr-default.json")

  parameters_content = jsonencode({
    "dataCollectionRuleName" = {
      "value" : "ama-linux-dcr-default"
    },
    "location" = {
      "value" : azurerm_resource_group.siem.location,
    },
    "workspaceResourceId" = {
      "value" : azurerm_log_analytics_workspace.siem.id
    },
    "endpointResourceId" = {
      "value" : azurerm_monitor_data_collection_endpoint.ama_dce.id
    }
  })

  depends_on = [time_sleep.wait_for_sentinel_tables]
}

resource "azurerm_user_assigned_identity" "ama_remediation" {
  name                = "ama-onboarding-remediator"
  resource_group_name = azurerm_resource_group.siem.name
  location            = azurerm_resource_group.siem.location
}

resource "azurerm_role_assignment" "ama_remediation_arc" {
  for_each = toset([
    "Azure Connected Machine Resource Administrator",
    "Log Analytics Contributor",
    "Monitoring Contributor",
    "Virtual Machine Contributor"
  ])

  scope                = azurerm_resource_group.arc.id
  role_definition_name = each.key
  principal_id         = azurerm_user_assigned_identity.ama_remediation.principal_id
}

resource "azurerm_role_assignment" "ama_remediation_siem" {
  scope                = azurerm_resource_group.siem.id
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_user_assigned_identity.ama_remediation.principal_id
}

resource "azurerm_resource_group_policy_assignment" "ama_onboard_linux" {
  name                 = "Install Azure Monitor Agent on Linux hosts"
  resource_group_id    = azurerm_resource_group.arc.id
  location             = azurerm_resource_group.arc.location
  policy_definition_id = data.azurerm_policy_set_definition.ama_onboard_linux.id

  parameters = jsonencode({
    "dcrResourceId" = {
      "value" : data.azurerm_monitor_data_collection_rule.ama_linux_dcr_default.id
    }
  })

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ama_remediation.id]
  }
}
