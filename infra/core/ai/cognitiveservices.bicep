metadata description = 'Creates an Azure Cognitive Services instance.'
param name string
param location string = resourceGroup().location
param tags object = {}
@description('The custom subdomain name used to access the API. Defaults to the value of the name parameter.')
param customSubDomainName string = name
param disableLocalAuth bool = false
param deployments array = []
param kind string = 'OpenAI'

param privateDnsZoneId string
param useNetIsolation bool = false
param subnetID string = ''


@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}

param allowedIpRules array = []
param networkAcls object = empty(allowedIpRules) ? {
  defaultAction: 'Allow'
} : {
  ipRules: allowedIpRules
  defaultAction: 'Deny'
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkAcls
    disableLocalAuth: disableLocalAuth
  }
  sku: sku
}


resource privateEndPoint 'Microsoft.Network/privateEndpoints@2021-02-01' = if (useNetIsolation) {
  name: '${account.name}-privateEndpoint'
  location: location
  properties: {
    subnet: {
      id: useNetIsolation ? subnetID : null
    }
    privateLinkServiceConnections: [
      {
        name: '${account.name}-privateep'
        properties: {
          privateLinkServiceId: account.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }

  resource privateDnsGroup 'privateDnsZoneGroups@2023-09-01' = if (useNetIsolation){
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink_openai_azure_com'
          properties: {
            privateDnsZoneId: useNetIsolation ? privateDnsZoneId : null
          }
        }
      ]
    }
  }
}



@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: account
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 20
  }
}]

output endpoint string = account.properties.endpoint
output id string = account.id
output name string = account.name
