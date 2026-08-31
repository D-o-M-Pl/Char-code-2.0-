// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

// Copyright 2026 D-o-M-Pl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param appName string = 'char-code'
param environmentName string = 'prod'

@secure()
param postgresAdminPassword string

var suffix = uniqueString(resourceGroup().id, appName, environmentName)
var planName = '${appName}-plan-${suffix}'
var webName = '${appName}-web-${suffix}'
var apiName = '${appName}-api-${suffix}'
var kvName = '${appName}-kv-${suffix}'
var pgName = '${appName}-pg-${suffix}'
var afdName = '${appName}-afd-${suffix}'
var wafName = '${appName}-waf-${suffix}'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${appName}-vnet-${suffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.60.0.0/16']
    }
    subnets: [
      {
        name: 'apps'
        properties: {
          addressPrefix: '10.60.1.0/24'
          delegations: [
            {
              name: 'appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'private-endpoints'
        properties: {
          addressPrefix: '10.60.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
  }
}

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: pgName
  location: location
  sku: {
    name: 'Standard_D2ds_v5'
    tier: 'GeneralPurpose'
  }
  properties: {
    version: '16'
    administratorLogin: 'charadmin'
    administratorLoginPassword: postgresAdminPassword
    storage: {
      storageSizeGB: 128
    }
    backup: {
      backupRetentionDays: 14
    }
    authConfig: {
      passwordAuth: 'Enabled'
      activeDirectoryAuth: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Disabled'
    }
  }
}

resource postgresPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${pgName}-pe'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'private-endpoints')
    }
    privateLinkServiceConnections: [
      {
        name: '${pgName}-connection'
        properties: {
          privateLinkServiceId: postgres.id
          groupIds: ['postgresqlServer']
        }
      }
    ]
  }
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
  }
  properties: {
    reserved: true
  }
}

resource web 'Microsoft.Web/sites@2024-04-01' = {
  name: webName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    siteConfig: {
      linuxFxVersion: 'NODE|22-lts'
      minTlsVersion: '1.3'
      ftpsState: 'Disabled'
      alwaysOn: true
      ipSecurityRestrictions: [
        {
          tag: 'ServiceTag'
          ipAddress: 'AzureFrontDoor.Backend'
          action: 'Allow'
          priority: 100
          name: 'Allow exact Azure Front Door'
          headers: {
            'x-azure-fdid': [
              frontDoor.properties.frontDoorId
            ]
          }
        }
      ]
      ipSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsUseMain: true
    }
  }
}

resource api 'Microsoft.Web/sites@2024-04-01' = {
  name: apiName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    siteConfig: {
      linuxFxVersion: 'NODE|22-lts'
      minTlsVersion: '1.3'
      ftpsState: 'Disabled'
      alwaysOn: true
    }
  }
}

resource frontDoor 'Microsoft.Cdn/profiles@2024-09-01' = {
  name: afdName
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
}

resource waf 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2024-05-01' = {
  name: wafName
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
        }
      ]
    }
  }
}

output webAppName string = web.name
output apiAppName string = api.name
output keyVaultName string = keyVault.name
output postgresName string = postgres.name
output frontDoorProfile string = frontDoor.name
output wafPolicy string = waf.name

// Production ingress additions: Front Door endpoint, origin group, route, WAF association,
// and Key Vault Private Endpoint/DNS. These resources intentionally use the Web app as the
// only public origin.

resource keyVaultDns 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
}

resource keyVaultDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: keyVaultDns
  name: '${appName}-kv-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${kvName}-pe'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'private-endpoints')
    }
    privateLinkServiceConnections: [
      {
        name: '${kvName}-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource postgresDns 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
}

resource postgresDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: postgresDns
  name: '${appName}-postgres-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-09-01' = {
  parent: frontDoor
  name: '${appName}-${suffix}'
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2024-09-01' = {
  parent: frontDoor
  name: 'web-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 60
    }
    sessionAffinityState: 'Disabled'
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-09-01' = {
  parent: frontDoorOriginGroup
  name: 'web-origin'
  properties: {
    hostName: '${web.name}.azurewebsites.net'
    originHostHeader: '${web.name}.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-09-01' = {
  parent: frontDoorEndpoint
  name: 'default-route'
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

resource frontDoorSecurityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2024-09-01' = {
  parent: frontDoor
  name: 'waf-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: waf.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

output frontDoorHostName string = frontDoorEndpoint.properties.hostName


resource appServicePrivateDns 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}
resource appServicePrivateDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: appServicePrivateDns
  name: '${appName}-appservice-link'
  location: 'global'
  properties: { registrationEnabled: false virtualNetwork: { id: vnet.id } }
}
resource apiPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${apiName}-pe'
  location: location
  properties: {
    subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'private-endpoints') }
    privateLinkServiceConnections: [{
      name: '${apiName}-private-link'
      properties: { privateLinkServiceId: api.id groupIds: ['sites'] }
    }]
  }
}
resource apiPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: apiPrivateEndpoint
  name: 'default'
  properties: { privateDnsZoneConfigs: [{ name: 'appservice' properties: { privateDnsZoneId: appServicePrivateDns.id } }] }
}