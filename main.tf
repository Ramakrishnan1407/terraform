
terraform {
    required_providers  {
        azurerm =   {
            source  =   "hashicorp/azurerm"
        }
    }
	
	backend "azurerm" {
    resource_group_name  = "terraformstate"
    storage_account_name = "terraformstate1407"
    container_name       = "terraformdemo"
    key                  = "dev.terraform.tfstate"
  }
}

# Provider Block

provider "azurerm" {
    version         =   "~> 2.0"
    client_id       =   var.client_id
    client_secret   =   var.client_secret
    subscription_id =   var.subscription_id
    tenant_id       =   var.tenant_id
    
    features {}
}

provider "azuread" {
    version         =   ">= 0.11"
    client_id       =   var.client_id
    client_secret   =   var.client_secret
    tenant_id       =   var.tenant_id
    alias           =   "ad"
}

data "azurerm_image" "packer-image" {
  name                = "myPackerImage"
  resource_group_name = "packer"
}

data "azurerm_resource_group" "rg" {
    name                  =   var.prefix
    location              =   var.location
}

resource "azurerm_virtual_network" "vnet" {
    name                  =   "${var.prefix}-vnet"
    resource_group_name   =   azurerm_resource_group.rg.name
    location              =   azurerm_resource_group.rg.location
    address_space         =   [var.vnet_address_range]
    tags                  =   var.tags
}

resource "azurerm_subnet" "sn" {
    for_each              =   var.subnets
    name                  =   each.key
    resource_group_name   =   azurerm_resource_group.rg.name
    virtual_network_name  =   azurerm_virtual_network.vnet.name
    address_prefixes      =   [each.value]
}

resource "azurerm_network_security_group" "nsg" {
    name                        =       "${var.prefix}-web-nsg"
    resource_group_name         =       azurerm_resource_group.rg.name
    location                    =       azurerm_resource_group.rg.location
    tags                        =       var.tags

    security_rule {
    name                        =       "Allow_RDP"
    priority                    =       1000
    direction                   =       "Inbound"
    access                      =       "Allow"
    protocol                    =       "Tcp"
    source_port_range           =       "*"
    destination_port_range      =       3389
    source_address_prefix       =       "122.172.42.146" 
    destination_address_prefix  =       "*"
    
    }
}

resource "azurerm_subnet_network_security_group_association" "server-subnet-nsg" {
    subnet_id                    =       azurerm_subnet.sn["server-subnet"].id
    network_security_group_id    =       azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "member-subnet-nsg" {
    subnet_id                    =       azurerm_subnet.sn["member-subnet"].id
    network_security_group_id    =       azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "pip" {
    name                            =     "${var.prefix}-public-ip"
    resource_group_name             =     azurerm_resource_group.rg.name
    location                        =     azurerm_resource_group.rg.location
    allocation_method               =     var.allocation_method[0]
    tags                            =     var.tags
}

resource "azurerm_network_interface" "nic" {
    name                              =   "${var.prefix}-nic"
    resource_group_name               =   azurerm_resource_group.rg.name
    location                          =   azurerm_resource_group.rg.location
    tags                              =   var.tags
    ip_configuration                  {
        name                          =  "${var.prefix}-nic-ipconfig"
        subnet_id                     =   azurerm_subnet.sn["server-subnet"].id
        public_ip_address_id          =   azurerm_public_ip.pip.id
        private_ip_address_allocation =   var.allocation_method[1]
    }
}

resource "azurerm_windows_virtual_machine" "vm" {
    name                              =   "${var.prefix}-vm"
    resource_group_name               =   azurerm_resource_group.rg.name
    location                          =   azurerm_resource_group.rg.location
    network_interface_ids             =   [azurerm_network_interface.nic.id]
    size                              =   var.virtual_machine_size
    computer_name                     =   var.computer_name
    admin_username                    =   var.admin_username
    admin_password                    =   var.admin_password

    os_disk  {
        name                          =   "${var.prefix}-os-disk"
        caching                       =   var.os_disk_caching
        storage_account_type          =   var.os_disk_storage_account_type
        disk_size_gb                  =   var.os_disk_size_gb
    }

    source_image_id = data.azurerm_image.packer-image.id
    tags                              =   var.tags

}

