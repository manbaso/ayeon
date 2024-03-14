# Define variables
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.94.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}


variable "vm_count" {
  default = 3
}


resource "azurerm_resource_group" "project_2" {
  name     = "project_2-resources"
  location = "East US"
}

resource "azurerm_virtual_network" "project_2" {
  name                = "project_2-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.project_2.location
  resource_group_name = azurerm_resource_group.project_2.name
}

resource "azurerm_subnet" "project_2" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.project_2.name
  virtual_network_name = azurerm_virtual_network.project_2.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "project_2" {
#   count               = var.vm_count
  name                = "project_2-public-ip"
  location            = azurerm_resource_group.project_2.location
  resource_group_name = azurerm_resource_group.project_2.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "project_2" {
  count               = var.vm_count
  name                = "project_2-nic-${count.index}"
  location            = azurerm_resource_group.project_2.location
  resource_group_name = azurerm_resource_group.project_2.name

  ip_configuration {
    name                          = "project_2-nic-ipconfig-${count.index}"
    subnet_id                     = azurerm_subnet.project_2.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.project_2.id
  }
}

resource "azurerm_linux_virtual_machine" "project_2" {
  count               = var.vm_count 
  name                = "project-vm-${count.index + 1}"
  resource_group_name = azurerm_resource_group.project_2.name
  location            = azurerm_resource_group.project_2.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"

  tags = { "env" : "Dev"}   
  
  network_interface_ids = [azurerm_network_interface.project_2[count.index].id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("project.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

 

}

output "vm_ids" {
  value = [for vm in azurerm_linux_virtual_machine.project_2 : vm.id]
}

resource "azurerm_storage_account" "project_2" {
  name                     = "ayerdiijujranowetgnt9" // Specify your preferred name
  resource_group_name      = azurerm_resource_group.project_2.name // Reference to an existing resource group or create a new one
  location                 = "East US" // Choose the appropriate location
  account_tier             = "Standard" // Choose between Standard or Premium
  account_replication_type = "LRS" // Choose the replication type (LRS, GRS, ZRS, RAGRS)
}

resource "azurerm_storage_container" "project_2" {
  name                  = "project-container"
  storage_account_name  = azurerm_storage_account.project_2.name
  container_access_type = "private"
}


# resource "azurerm_monitor_diagnostic_setting" "project_2" {

#   # for_each = toset(azurerm_linux_virtual_machine.project_2)
#   # for_each = azurerm_linux_virtual_machine.project_2
#    for_each = tomap({
#     for s in azurerm_linux_virtual_machine.project_2 : s.name => s.id
#   })
  
#   name                = each.key
#   target_resource_id = each.value
#   storage_account_id = azurerm_storage_account.project_2.id
#   log {
#     category = "AllMetrics"
#     enabled  = true

#     retention_policy {
#       enabled = true
#       days    = 30
#     }
#   }
# }

################

resource "azurerm_log_analytics_workspace" "project_2" {
  
  #  for_each = tomap({
  #   for s in azurerm_resource_group.project_2 : s.name => s.location
    
  # })
  
  name                = "vminsights-logAnalytics"
  location            = "East US" #which region your VM resides 
  resource_group_name = azurerm_resource_group.project_2.name # where your VM resides in your subscription
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_solution" "project_2" {

    # for key in keys(var.data1) : key => {
    #   data1_value = var.data1[key]
    #   data2_value = var.data2[key]
    # }
  #  for_each = tomap({
  #   for s in azurerm_log_analytics_workspace.project_2 : s.name => s.id
    
  # })
  # # name     = "project_2-resources"
  # location = "East US"

  solution_name         = "ContainerInsights"
  location              =  "East US" # which region your VM resides 
  resource_group_name   = "project_2-resources" # where your VM resides in your subscription
  workspace_resource_id = azurerm_log_analytics_workspace.project_2.id
  workspace_name        = azurerm_log_analytics_workspace.project_2.name
  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}
# Agent for Linux
# resource "azurerm_virtual_machine_extension" "OMS" {

#   for_each = tomap({
#     for s in azurerm_linux_virtual_machine.project_2 : s.name => s.id
#   })
#   name                       = "test-OMSExtension"
#   virtual_machine_id         =  each.value
#   publisher            = "Microsoft.Azure.Monitoring.Insights"
#   type                 = "MonitoringAgent"
#   type_handler_version = "10.0"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
#     {
#       "workspaceId" : "${azurerm_log_analytics_workspace.project_2.workspace_id}"
#     }
#   SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#     {
#       "workspaceKey" : "${azurerm_log_analytics_workspace.project_2.primary_shared_key}"
#     }
#   PROTECTED_SETTINGS
# }

# # Dependency Agent for Linux
# resource "azurerm_virtual_machine_extension" "da" {
#   for_each = tomap({
#     for s in azurerm_linux_virtual_machine.project_2 : s.name => s.id
#   })
#   name                       = "DAExtension"
#   virtual_machine_id         =  each.value
  
#   publisher            = "Microsoft.Azure.Monitoring.VMDependencyAgent"
#   type                 = "DependencyAgentLinux"
#   type_handler_version = "9.5"
#   auto_upgrade_minor_version = true

# }

 resource "azurerm_virtual_machine_extension" "AzureMonitorLinuxAgent" { 
      
      for_each = tomap({
        for s in azurerm_linux_virtual_machine.project_2 : s.name => s.id
      })
      
      virtual_machine_id         =  each.value

      name                       = "AzureMonitorLinuxAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorLinuxAgent"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = "true"
    
      
    }




resource "azurerm_user_assigned_identity" "project_2" {
  name                = "project_2-identity"
  resource_group_name = azurerm_resource_group.project_2.name
  location            = azurerm_resource_group.project_2.location
}


resource "azurerm_monitor_data_collection_endpoint" "project_2" {
  name                = "project1-dcre"
  resource_group_name = azurerm_resource_group.project_2.name
  location            = azurerm_resource_group.project_2.location

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_monitor_data_collection_rule" "project_2" {
  name                        = "project_2-rule"
  resource_group_name         = azurerm_resource_group.project_2.name
  location                    = azurerm_resource_group.project_2.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.project_2.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.project_2.id
      name                  = "project1-destination-logs"
    }

    # event_hub {
    #   event_hub_id = azurerm_eventhub.project_2.id
    #   name         = "project_2-destination-eventhub"
    # }

    storage_blob {
      storage_account_id = azurerm_storage_account.project_2.id
      container_name     = azurerm_storage_container.project_2.name
      name               = "project1-destination-log"
    }

    azure_monitor_metrics {
      name = "project1-destination-loga"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["project1-destination-log"]
    # destinations   = ["la--1802282221"]
      transform_kql  = "source"
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics", "Microsoft-Syslog", "Microsoft-Perf"]
    destinations = ["project1-destination-logs"]
    # destinations   = ["la--1802282221"]
    transform_kql  = "source"
  }

  # data_flow {
  #   streams       = ["Custom-MyTableRawData"]
  #   destinations  = ["project1-destination-log"]
  #   destinations   = ["la--1802282221"]
  #   transform_kql  = "source"
  #   output_stream = "Microsoft-Syslog"
  #   # transform_kql = "source | projectt TimeGenerated = Time, Computer, Message = AdditionalContext"
  # }

  data_sources {
    syslog {
      facility_names = ["*"]
      log_levels     = ["*"]
      name           = "project_2-datasource-syslog"
      streams        = ["Microsoft-Syslog"]
    }

    

    # log_file {
    #   name          = "project_2-datasource-logfile"
    #   format        = "text"
    #   streams       = ["Custom-MyTableRawData"]
    #   file_patterns = ["C:\\JavaLogs\\*.log"]
    #   settings {
    #     text {
    #       record_start_timestamp_format = "ISO 8601"
    #     }
    #   }
    # }

    performance_counter {
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = ["Processor(*)\\% Processor Time"]
      name                          = "project_2-datasource-perfcounter"
    }

    # windows_event_log {
    #   streams        = ["Microsoft-WindowsEvent"]
    #   x_path_queries = ["*![System/Level=1]"]
    #   name           = "project_2-datasource-wineventlog"
    # }

    # extension {
    #   streams            = ["Microsoft-WindowsEvent"]
    #   input_data_sources = ["project_2-datasource-wineventlog"]
    #   extension_name     = "project_2-extension-name"
    #   extension_json = jsonencode({
    #     a = 1
    #     b = "hello"
    #   })
    #   name = "project_2-datasource-extension"
    # }
  }

  

  stream_declaration {
    stream_name = "Custom-MyTableRawData"
    column {
      name = "Time"
      type = "datetime"
    }
    column {
      name = "Computer"
      type = "string"
    }
    column {
      name = "AdditionalContext"
      type = "string"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.project_2.id]
  }

  description = "data collection rule project_2"
  tags = {
    foo = "bar"
  }
  depends_on = [
    azurerm_log_analytics_solution.project_2
  ]
}

resource "azurerm_monitor_data_collection_rule_association" "project_2" {
  name                    = "project1-dcra"
  # data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.project_2.id
  for_each = tomap({
        for s in azurerm_linux_virtual_machine.project_2 : s.name => s.id
      })
  target_resource_id      = each.value
  data_collection_rule_id = azurerm_monitor_data_collection_rule.project_2.id
  description             = "project_2"
}

resource "azurerm_monitor_action_group" "project_2" {
  name                = "CriticalAlertsAction"
  resource_group_name = azurerm_resource_group.project_2.name
  short_name          = "p0action"

  email_receiver {
    name                    = "sendtoadmin"
    email_address           = "ayoxdele@gmail.com"
    use_common_alert_schema = true
  }
}

data "azurerm_subscription" "current" {

  
}

resource "azurerm_monitor_metric_alert" "project_2" {
  for_each = tomap({
        for s in azurerm_linux_virtual_machine.project_2 : s.name => s.id
      })
  name                = each.key
  resource_group_name = azurerm_resource_group.project_2.name
  scopes              = [each.value]
  description         = "Action will be triggered when Transactions count is greater than 50."

  criteria { 
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Total"
    operator         = "LessThan"
    threshold        = 50
  }
    criteria { 
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Total"
    operator         = "LessThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.project_2.id
  }

  
}
