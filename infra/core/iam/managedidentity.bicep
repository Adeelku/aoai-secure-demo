param location string = resourceGroup().location
param name string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: name
  location: location
}


output uaID string = managedIdentity.id
output uaPrincipalId string = managedIdentity.properties.principalId
output uaClientId string = managedIdentity.properties.clientId
