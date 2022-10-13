# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.80.0"
    }
  }
  backend "azurerm" {
    # assign storage to store tfstate file
    resource_group_name  = "tm-terraform"
    storage_account_name = "sg4terraform"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
    use_msi = true
    features {
      key_vault {
        purge_soft_delete_on_destroy = true
      }
    }
}

# Create service principle
data "azuread_client_config" "current" {}
# data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "DumpFile" {
  name     = var.RGName
  location = var.location
}

#storage account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage
  resource_group_name      = var.RGName
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [ azurerm_resource_group.DumpFile ]
}

resource "azurerm_storage_container" "container" {
  name                  = var.container
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
  depends_on = [ azurerm_resource_group.DumpFile ]
}


# event grid
resource "azurerm_eventgrid_system_topic" "dumpupload" {
  name                   = var.eventgrid
  resource_group_name    = var.RGName
  location               = var.location
  source_arm_resource_id = azurerm_storage_account.storage.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
}

resource "azurerm_eventgrid_event_subscription" "evtFileReceived" {
  name  = "evtFileReceived"
  scope = azurerm_storage_account.storage.id
  topic_name = azurerm_storage_account.storage.id
  service_bus_queue_endpoint_id = azurerm_servicebus_queue.sbus-queue.id 
  advanced_filtering_on_arrays_enabled = false 

  advanced_filter {
        string_not_contains {
            key = "subject" 
            values = [ "azure" ]
        }
    }
  
}

#fun app
resource "azurerm_app_service_plan" "plan" {
  name                = var.funcplan
  location            = var.location
  resource_group_name = var.RGName

  sku {
    tier = "Standard"
    size = "S1"
  }
  depends_on = [ azurerm_resource_group.DumpFile ]
}

resource "azurerm_function_app" "func" {
  name                       = var.funcapp
  location                   = var.location
  resource_group_name        = var.RGName
  app_service_plan_id        = azurerm_app_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
}

# service bus upload
resource "azurerm_servicebus_namespace" "servicebus" {
  name                = var.sbus1
  location            = var.location
  resource_group_name = var.RGName
  sku                 = "Standard"

  tags = {
    source = "terraform"
  }
  depends_on = [ azurerm_resource_group.DumpFile ]
}

resource "azurerm_servicebus_queue" "sbus-queue" {
  name                = "dumpuploadqueue"
  resource_group_name = var.RGName
  namespace_name      = azurerm_servicebus_namespace.servicebus.name

  enable_partitioning = true
}
resource "azurerm_servicebus_queue_authorization_rule" "sbus-queue-upload" {
  name     = "uploadqueuerule"
  resource_group_name = var.RGName
  namespace_name = var.sbus1
  queue_name = azurerm_servicebus_queue.sbus-queue.name
  listen = true
  send   = true
  manage = true
}

# service bus XL
resource "azurerm_servicebus_namespace" "servicebusXL" {
  name                = var.sbusXL
  location            = var.location
  resource_group_name = var.RGName
  sku                 = "Standard"

  tags = {
    source = "terraform"
  }
  depends_on      = [ azurerm_resource_group.DumpFile ]
}
resource "azurerm_servicebus_queue" "sbus-queue-xl" {
  name                = "xlqueue"
  resource_group_name = var.RGName
  namespace_name      = azurerm_servicebus_namespace.servicebusXL.name

  enable_partitioning = true
}
resource "azurerm_servicebus_queue_authorization_rule" "sbus-queue-xl" {
  name     = "xlqueuerule"
  resource_group_name = var.RGName
  namespace_name = var.sbusXL
  queue_name = azurerm_servicebus_queue.sbus-queue-xl.name
  listen = true
  send   = true
  manage = true # keda needed
}

# service bus L
resource "azurerm_servicebus_namespace" "servicebusL" {
  name                = var.sbusL
  location            = var.location
  resource_group_name = var.RGName
  sku                 = "Standard"

  tags = {
    source = "terraform"
  }
  depends_on      = [ azurerm_resource_group.DumpFile ]
}
resource "azurerm_servicebus_queue" "sbus-queue-l" {
  name                = "lqueue"
  resource_group_name = var.RGName
  namespace_name      = azurerm_servicebus_namespace.servicebusL.name

  enable_partitioning = true
}
resource "azurerm_servicebus_queue_authorization_rule" "sbus-queue-l" {
  name     = "lqueuerule"
  resource_group_name = var.RGName
  namespace_name = var.sbusL
  queue_name = azurerm_servicebus_queue.sbus-queue-l.name
  listen = true
  send   = true
  manage = true
}
# service bus M
resource "azurerm_servicebus_namespace" "servicebusM" {
  name                = var.sbusM
  location            = var.location
  resource_group_name = var.RGName
  sku                 = "Standard"

  tags = {
    source = "terraform"
  }
  depends_on      = [ azurerm_resource_group.DumpFile ]
}
resource "azurerm_servicebus_queue" "sbus-queue-m" {
  name                = "mqueue"
  resource_group_name = var.RGName
  namespace_name      = azurerm_servicebus_namespace.servicebusM.name

  enable_partitioning = true
}

resource "azurerm_servicebus_queue_authorization_rule" "sbus-queue-m" {
  name     = "mqueuerule"
  resource_group_name = var.RGName
  namespace_name = var.sbusM
  queue_name = azurerm_servicebus_queue.sbus-queue-m.name
  listen = true
  send   = true
  manage = true
}

# Keyvault
resource "azurerm_key_vault" "keyvault" {
  name                        = var.keyvault
  location                    = var.location
  resource_group_name         = var.RGName
  enabled_for_disk_encryption = true
  tenant_id                   = data.azuread_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
  
  access_policy {
    tenant_id = data.azuread_client_config.current.tenant_id
    object_id = data.azuread_client_config.current.object_id

    certificate_permissions = [
      "Get","Create", "Delete", "Update", "List", "DeleteIssuers", "GetIssuers", "ListIssuers", "ManageContacts", "ManageIssuers"
    ]

    key_permissions = [
      "Get","Create", "Delete", "Update", "List"
    ]

    secret_permissions = [
      "Delete", "Get", "List", "Purge", "Set"
    ]

    storage_permissions = [
      "Delete", "DeleteSAS", "Get", "GetSAS", "List", "ListSAS", "Purge", "Set", "SetSAS", "Update"
    ]
  }
  depends_on = [ azurerm_resource_group.DumpFile ]
}
resource "azurerm_key_vault_secret" "upload-queue" {
  name         = "secret-upload-queue-connection"
  value        = azurerm_servicebus_queue_authorization_rule.sbus-queue-upload.primary_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "m-queue" {
  name         = "secret-m-queue-connection"
  value        = azurerm_servicebus_queue_authorization_rule.sbus-queue-m.primary_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "l-queue" {
  name         = "secret-l-queue-connection"
  value        = azurerm_servicebus_queue_authorization_rule.sbus-queue-l.primary_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "xl-queue" {
  name         = "secret-xl-queue-connection"
  value        = azurerm_servicebus_queue_authorization_rule.sbus-queue-xl.primary_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "sg-key" {
  name         = "secret-sg-key"
  value        = azurerm_storage_account.storage.primary_access_key
  key_vault_id = azurerm_key_vault.keyvault.id
}


# App Configuration
resource "azurerm_app_configuration" "appconf" {
  name                = var.appConf
  resource_group_name = var.RGName
  location            = var.location
  sku = "standard"
  depends_on = [ azurerm_resource_group.DumpFile ]
}

# Add key-value to app config
locals {
  appconfig = {
    RGName = azurerm_resource_group.DumpFile.name
    aks = azurerm_kubernetes_cluster.aks.name
    sbus1 = azurerm_servicebus_namespace.servicebus.name
    sbus-queue = azurerm_servicebus_queue.sbus-queue.name
    sbusXL = azurerm_servicebus_namespace.servicebusXL.name
    sbus-queue-xl = azurerm_servicebus_queue.sbus-queue-xl.name
    sbusL = azurerm_servicebus_namespace.servicebusL.name
    sbus-queue-l = azurerm_servicebus_queue.sbus-queue-l.name
    sbusM = azurerm_servicebus_namespace.servicebusM.name
    sbus-queue-m = azurerm_servicebus_queue.sbus-queue-m.name

  }
  keyvault_ref = {
    (azurerm_key_vault_secret.upload-queue.name) = azurerm_key_vault_secret.upload-queue.id
    (azurerm_key_vault_secret.m-queue.name) = azurerm_key_vault_secret.m-queue.id
    (azurerm_key_vault_secret.l-queue.name) = azurerm_key_vault_secret.l-queue.id
    (azurerm_key_vault_secret.xl-queue.name) = azurerm_key_vault_secret.xl-queue.id
  }
}

resource "null_resource" "demo_config_values" {
  for_each = local.appconfig

  provisioner "local-exec" {
    command = "az appconfig kv set --connection-string $CONNECTION_STRING --key $KEY --value $VALUE --yes"

    environment = {
      CONNECTION_STRING = azurerm_app_configuration.appconf.primary_write_key.0.connection_string
      KEY               = each.key
      VALUE             = each.value
    }
  }
}


resource "null_resource" "demo_config_values_with_keyvault" {

  for_each = local.keyvault_ref

  provisioner "local-exec" {
    command = "az appconfig kv set-keyvault --connection-string $CONNECTION_STRING --key $KEY --secret-identifier $SECRET_ID --yes"
    environment = {
      CONNECTION_STRING = azurerm_app_configuration.appconf.primary_write_key.0.connection_string
      KEY               = each.key
      SECRET_ID         = each.value
    }
  }
}
