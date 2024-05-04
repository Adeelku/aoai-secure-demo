param vnetName string
param location string
param addressPrefix string = '10.0.0.0/16'
param subnets array = [
  {
    name: 'default'
    addressPrefix: '10.0.1.0/24'
  }
  {
    name: 'privateendpoints'
    addressPrefix: '10.0.2.0/24'
  }
  {
    name: 'webapp'
    addressPrefix: '10.0.3.0/28'
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          delegations: !empty(subnet.delegation) ?  [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ] : []
        }
      }
    ]
  }
}

resource createprivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: createprivateDnsZone
  name: 'privatelink'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}
output privateDnsZoneId string = createprivateDnsZone.id
output PrivateEndPointId string = '${vnet.id}/subnets/privateendpoints'
output defaultId string = '${vnet.id}/subnets/default'
output webID string = '${vnet.id}/subnets/webapp'
