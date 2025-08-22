@description('Virtual Network name')
param vnetName string

@description('Azure region for resource deployment')
param location string

@description('Resource tags')
param tags object

@description('Environment name for sizing decisions')
param environment string

// Network configuration based on environment
var networkConfig = {
  dev: {
    vnetAddressSpace: '10.1.0.0/16'
    containerAppSubnet: '10.1.1.0/24'
    databaseSubnet: '10.1.2.0/24'
    privateEndpointSubnet: '10.1.3.0/24'
    applicationGatewaySubnet: '10.1.4.0/24'
  }
  staging: {
    vnetAddressSpace: '10.2.0.0/16'
    containerAppSubnet: '10.2.1.0/24'
    databaseSubnet: '10.2.2.0/24'
    privateEndpointSubnet: '10.2.3.0/24'
    applicationGatewaySubnet: '10.2.4.0/24'
  }
  prod: {
    vnetAddressSpace: '10.0.0.0/16'
    containerAppSubnet: '10.0.1.0/24'
    databaseSubnet: '10.0.2.0/24'
    privateEndpointSubnet: '10.0.3.0/24'
    applicationGatewaySubnet: '10.0.4.0/24'
  }
}

var selectedConfig = networkConfig[environment]

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        selectedConfig.vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'snet-containerapp'
        properties: {
          addressPrefix: selectedConfig.containerAppSubnet
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'snet-database'
        properties: {
          addressPrefix: selectedConfig.databaseSubnet
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
          delegations: [
            {
              name: 'Microsoft.DBforPostgreSQL.flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: 'snet-privateendpoint'
        properties: {
          addressPrefix: selectedConfig.privateEndpointSubnet
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-applicationgateway'
        properties: {
          addressPrefix: selectedConfig.applicationGatewaySubnet
        }
      }
    ]
  }
}

// Network Security Group for Container Apps
resource containerAppNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-containerapp-${environment}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1010
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowContainerAppPorts'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1020
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Network Security Group for Database
resource databaseNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-database-${environment}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowPostgreSQLFromContainerApp'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5432'
          sourceAddressPrefix: selectedConfig.containerAppSubnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Network Security Group for Private Endpoints
resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-privateendpoint-${environment}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVNetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Associate NSGs with subnets
resource containerAppSubnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnet
  name: 'snet-containerapp'
  properties: {
    addressPrefix: selectedConfig.containerAppSubnet
    networkSecurityGroup: {
      id: containerAppNsg.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.ContainerRegistry'
      }
    ]
    delegations: [
      {
        name: 'Microsoft.App.environments'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}

resource databaseSubnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnet
  name: 'snet-database'
  properties: {
    addressPrefix: selectedConfig.databaseSubnet
    networkSecurityGroup: {
      id: databaseNsg.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
    delegations: [
      {
        name: 'Microsoft.DBforPostgreSQL.flexibleServers'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      }
    ]
  }
}

resource privateEndpointSubnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnet
  name: 'snet-privateendpoint'
  properties: {
    addressPrefix: selectedConfig.privateEndpointSubnet
    networkSecurityGroup: {
      id: privateEndpointNsg.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

// Private DNS Zone for PostgreSQL
resource postgresqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${environment}.postgres.database.azure.com'
  location: 'global'
  tags: tags
  properties: {}
}

// Link Private DNS Zone to VNet
resource postgresqlPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: postgresqlPrivateDnsZone
  name: 'link-${vnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private DNS Zone for Key Vault
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
  properties: {}
}

// Link Key Vault Private DNS Zone to VNet
resource keyVaultPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: 'link-kv-${vnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private DNS Zone for Container Registry
resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
  properties: {}
}

// Link ACR Private DNS Zone to VNet
resource acrPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: 'link-acr-${vnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Outputs
@description('Virtual Network ID')
output vnetId string = vnet.id

@description('Virtual Network Name')
output vnetName string = vnet.name

@description('Container App Subnet ID')
output containerAppSubnetId string = containerAppSubnetNsgAssociation.id

@description('Database Subnet ID')
output databaseSubnetId string = databaseSubnetNsgAssociation.id

@description('Private Endpoint Subnet ID')
output privateEndpointSubnetId string = privateEndpointSubnetNsgAssociation.id

@description('Application Gateway Subnet ID')
output applicationGatewaySubnetId string = '${vnet.id}/subnets/snet-applicationgateway'

@description('PostgreSQL Private DNS Zone ID')
output postgresqlPrivateDnsZoneId string = postgresqlPrivateDnsZone.id

@description('Key Vault Private DNS Zone ID')
output keyVaultPrivateDnsZoneId string = keyVaultPrivateDnsZone.id

@description('Container Registry Private DNS Zone ID')
output acrPrivateDnsZoneId string = acrPrivateDnsZone.id
