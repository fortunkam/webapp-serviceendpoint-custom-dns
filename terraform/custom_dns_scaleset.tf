resource "azurerm_network_security_group" "dns_vmss" {
  name                = local.dns_vmss_nsg
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_network_security_rule" "vmss_dns" {
  name                        = "dns"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hub.name
  network_security_group_name = azurerm_network_security_group.dns_vmss.name
}

resource "azurerm_windows_virtual_machine_scale_set" "dns" {
  name                  = local.dns_vmss
  location              = azurerm_resource_group.hub.location
  resource_group_name   = azurerm_resource_group.hub.name
  sku                   = "Standard_DS1_v2"
  instances             = 2
  admin_username        = var.dns_username
  admin_password        = random_password.dns_password.result
  provision_vm_agent    = true
  upgrade_mode          = "Automatic"
  health_probe_id       = azurerm_lb_probe.dns.id
  enable_automatic_updates = true

    automatic_os_upgrade_policy {
      disable_automatic_rollback = false
      enable_automatic_os_upgrade = true
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  os_disk {
    caching           = "ReadWrite"
    storage_account_type  = "Standard_LRS"
  }

  identity {
      type = "SystemAssigned"
  }

  network_interface {
      name = local.dns_vmss_internal_nic
      primary = true
      dns_servers  = [ local.azure_dns_server ]
      ip_configuration {
        name      = local.dns_vmss_internal_ipconfig
        primary   = true
        subnet_id = azurerm_subnet.vm.id
        load_balancer_backend_address_pool_ids = [ azurerm_lb_backend_address_pool.dns.id ]    
      }
      network_security_group_id = azurerm_network_security_group.dns_vmss.id
  }

  rolling_upgrade_policy {
      max_batch_instance_percent = "50"
      max_unhealthy_instance_percent = "50"
      max_unhealthy_upgraded_instance_percent = "50"
      pause_time_between_batches = "PT10M"
  }
}



resource "azurerm_virtual_machine_scale_set_extension" "installdns" {
  name                 = "installdns"
  virtual_machine_scale_set_id    = azurerm_windows_virtual_machine_scale_set.dns.id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.19"

  settings = <<SETTINGS
    {
        "ModulesURL": "${azurerm_storage_blob.dnsserverzip.url}${data.azurerm_storage_account_blob_container_sas.scripts.sas}", 
        "configurationFunction": "DNSServer.ps1\\DNSServer"
    }
SETTINGS

    lifecycle {
        ignore_changes = [
            settings
        ]
    }
}

resource "azurerm_virtual_machine_scale_set_extension" "configuredns" {
  name                 = "configuredns"
  virtual_machine_scale_set_id   = azurerm_windows_virtual_machine_scale_set.dns.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.8"

  settings = <<SETTINGS
    {
        "fileUris": [], 
        "commandToExecute": "powershell.exe Add-DnsServerConditionalForwarderZone -Name ${local.storage_data}.table.core.windows.net -MasterServers ${local.azure_dns_server} -PassThru"
    }
SETTINGS

    depends_on = [azurerm_virtual_machine_scale_set_extension.installdns]
}

resource "azurerm_lb" "dns" {
 name                = local.dns_loadbalancer_name
 location            = azurerm_resource_group.hub.location
 resource_group_name = azurerm_resource_group.hub.name

 frontend_ip_configuration {
   name                 = local.dns_vmss_frontend_IP_configuration_name
   private_ip_address = local.dns_server_private_ip
   private_ip_address_allocation = "Static"
   private_ip_address_version = "IPv4"
   subnet_id = azurerm_subnet.vm.id
 }
}

resource "azurerm_lb_backend_address_pool" "dns" {
 resource_group_name = azurerm_resource_group.hub.name
 loadbalancer_id     = azurerm_lb.dns.id
 name                = local.dns_loadbalancer_backend_address_pool
}

resource "azurerm_lb_probe" "dns" {
 resource_group_name = azurerm_resource_group.hub.name
 loadbalancer_id     = azurerm_lb.dns.id
 name                = "ssh-running-probe"
 port                = local.dns_port
}

resource "azurerm_lb_rule" "dns" {
   resource_group_name            = azurerm_resource_group.hub.name
   loadbalancer_id                = azurerm_lb.dns.id
   name                           = "dns"
   protocol                       = "Udp"
   frontend_port                  = local.dns_port
   backend_port                   = local.dns_port
   backend_address_pool_id        = azurerm_lb_backend_address_pool.dns.id
   frontend_ip_configuration_name = local.dns_vmss_frontend_IP_configuration_name
   probe_id                       = azurerm_lb_probe.dns.id
}




