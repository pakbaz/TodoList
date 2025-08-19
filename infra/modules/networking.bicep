targetScope = 'resourceGroup'

// =================
// PARAMETERS
// =================

@description('The name of the virtual network')
param vnetName string

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('The environment name (dev, staging, prod)')
param environment string

// =================
// VARIABLES
// =================

var nsgName = '${vnetName}-nsg'

// Environment-specific address spaces
var addressSpaces = {
  dev: '10.0.0.0/20'      // 10.0.0.0 - 10.0.15.255 (4094 addresses)
  staging: '10.16.0.0/20' // 10.16.0.0 - 10.16.15.255 (4094 addresses)
  prod: '10.32.0.0/20'    // 10.32.0.0 - 10.32.15.255 (4094 addresses)
}

var baseAddress = split(addressSpaces[environment], '/')[0]
var addressParts = split(baseAddress, '.')
var baseOctet = int(addressParts[2])

// Subnet definitions
var subnets = [
  {
    name: 'container-apps'
    addressPrefix: '${addressParts[0]}.${addressParts[1]}.${baseOctet}.0/23'     // /23 for Container Apps (required)
    delegation: 'Microsoft.App/environments'
  }
  {
    name: 'database'
    addressPrefix: '${addressParts[0]}.${addressParts[1]}.${baseOctet + 2}.0/24' // /24 for Database
    delegation: 'Microsoft.DBforPostgreSQL/flexibleServers'
  }
  {
    name: 'private-endpoints'
    addressPrefix: '${addressParts[0]}.${addressParts[1]}.${baseOctet + 3}.0/24' // /24 for Private Endpoints
    delegation: ''
  }
  {
    name: 'app-gateway'
    addressPrefix: '${addressParts[0]}.${addressParts[1]}.${baseOctet + 4}.0/24' // /24 for Application Gateway
    delegation: ''
  }
]

// =================
// NETWORK SECURITY GROUP
// =================

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          description: 'Allow HTTPS traffic'
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
          description: 'Allow HTTP traffic (will be redirected to HTTPS)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowPostgreSQL'
        properties: {
          description: 'Allow PostgreSQL traffic from Container Apps subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5432'
          sourceAddressPrefix: subnets[0].addressPrefix // Container Apps subnet
          destinationAddressPrefix: subnets[1].addressPrefix // Database subnet
          access: 'Allow'
          priority: 1200
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all other inbound traffic'
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

// =================
// VIRTUAL NETWORK
// =================

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpaces[environment]
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: contains(subnet.name, 'container-apps') || contains(subnet.name, 'database') ? {
          id: nsg.id
        } : null
        delegations: !empty(subnet.delegation) ? [
          {
            name: '${subnet.name}-delegation'
            properties: {
              serviceName: subnet.delegation
            }
          }
        ] : []
        privateEndpointNetworkPolicies: contains(subnet.name, 'private-endpoints') ? 'Disabled' : 'Enabled'
        privateLinkServiceNetworkPolicies: contains(subnet.name, 'private-endpoints') ? 'Disabled' : 'Enabled'
      }
    }]
  }
}

// =================
// OUTPUTS
// =================

@description('The resource ID of the virtual network')
output vnetId string = vnet.id

@description('The name of the virtual network')
output vnetName string = vnet.name

@description('The resource ID of the Container Apps subnet')
output containerAppsSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'container-apps')

@description('The resource ID of the database subnet')
output databaseSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'database')

@description('The resource ID of the private endpoints subnet')
output privateEndpointsSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'private-endpoints')

@description('The resource ID of the ACR subnet (using private endpoints subnet)')
output acrSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'private-endpoints')

@description('The resource ID of the Key Vault subnet (using private endpoints subnet)')
output keyVaultSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'private-endpoints')

@description('The resource ID of the Application Gateway subnet')
output appGatewaySubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'app-gateway')

@description('The resource ID of the network security group')
output nsgId string = nsg.id
