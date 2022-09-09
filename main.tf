# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  subscription_id = "4c9e41e7-50b1-45b6-aa16-9f9170eb8d12"
  tenant_id       = "effd9517-bc8e-43ec-bb31-d975c6fde3ac"
  version = "=2.37.0"
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "M2_rg" {
  name     = "${var.resource_prefix}-RG"
  location = var.node_location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "M2_vnet" {
  name                = "${var.resource_prefix}-vnet"
  resource_group_name = azurerm_resource_group.M2_rg.name
  location            = var.node_location
  address_space       = var.node_address_space
}

# Create a subnets within the virtual network
resource "azurerm_subnet" "M2_subnet" {
  name                 = "${var.resource_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.M2_rg.name
  virtual_network_name = azurerm_virtual_network.M2_vnet.name
  address_prefix       = var.node_address_prefix
}

# Create Linux Public IP
resource "azurerm_public_ip" "M2_public_ip" {
  count = var.node_count
  name  = "${var.resource_prefix}-${format("%02d", count.index)}-PublicIP"
  #name = “${var.resource_prefix}-PublicIP”
  location            = azurerm_resource_group.M2_rg.location
  resource_group_name = azurerm_resource_group.M2_rg.name
  allocation_method   = var.Environment == "Magento" ? "Static" : "Dynamic"

  tags = {
    environment = "Magento"
  }
}

# Create Network Interface
resource "azurerm_network_interface" "M2_nic" {
  count = var.node_count
  #name = “${var.resource_prefix}-NIC”
  name                = "${var.resource_prefix}-${format("%02d", count.index)}-NIC"
  location            = azurerm_resource_group.M2_rg.location
  resource_group_name = azurerm_resource_group.M2_rg.name
  #

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.M2_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.M2_public_ip.*.id, count.index)
    #public_ip_address_id = azurerm_public_ip.example_public_ip.id
    #public_ip_address_id = azurerm_public_ip.example_public_ip.id
  }
}

# Creating resource NSG
resource "azurerm_network_security_group" "M2_nsg" {

  name                = "${var.resource_prefix}-NSG"
  location            = azurerm_resource_group.M2_rg.location
  resource_group_name = azurerm_resource_group.M2_rg.name

  # Security rule can also be defined with resource azurerm_network_security_rule, here just defining it inline.
  security_rule {
    name                       = "Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"

  }
  tags = {
    environment = "Magento"
  }
}

# Subnet and NSG association
resource "azurerm_subnet_network_security_group_association" "M2_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.M2_subnet.id
  network_security_group_id = azurerm_network_security_group.M2_nsg.id

}

# Virtual Machine Creation — Linux
resource "azurerm_virtual_machine" "M2_linux_vm" {
  count = var.node_count
  name  = "${var.resource_prefix}-${format("%02d", count.index)}"
  #name = "${var.resource_prefix}-VM"
  location                      = azurerm_resource_group.M2_rg.location
  resource_group_name           = azurerm_resource_group.M2_rg.name
  network_interface_ids         = [element(azurerm_network_interface.M2_nic.*.id, count.index)]
  vm_size                       = "Standard_D2s_v3"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "magento"
    admin_username = "serverapprunner"
    admin_password = "P@ssw0rd12345"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
  environment = "Magento" }
}

