// ============================================
// Virtual Network with Enterprise Subnets
// ============================================

@description('Azure region for the VNet')
param location string

@description('Base name for resource naming')
param baseName string

@description('Tags to apply to resources')
param tags object = {}

@description('VNet address space prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Private endpoint subnet address prefix')
param privateEndpointSubnetPrefix string = '10.0.1.0/24'

@description('Agents and evaluations subnet address prefix')
param agentsSubnetPrefix string = '10.0.2.0/24'

// ============================================
// Variables
// ============================================

var vnetName = '${baseName}-vnet'
var privateEndpointSubnetName = 'private-endpoints-snet'
var agentsSubnetName = 'agents-snet'
var peNsgName = '${baseName}-pe-nsg'
var agentsNsgName = '${baseName}-agents-nsg'

// ============================================
// Network Security Groups
// ============================================

resource peNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: peNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource agentsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: agentsNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

// ============================================
// Virtual Network
// ============================================

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: peNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: agentsSubnetName
        properties: {
          addressPrefix: agentsSubnetPrefix
          networkSecurityGroup: {
            id: agentsNsg.id
          }
          delegations: [
            {
              name: 'Microsoft.app/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
    ]
  }
}

// ============================================
// Outputs
// ============================================

output vnetId string = vnet.id
output vnetName string = vnet.name
output privateEndpointSubnetId string = vnet.properties.subnets[0].id
output agentsSubnetId string = vnet.properties.subnets[1].id
