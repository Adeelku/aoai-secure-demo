param appName string
param subnetId string
param uaResourceId string
param uaClienId string
param azureOpenAiService string
param azureOpenAiGptDeployment string

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
param runtime string = 'python'

var functionAppName = appName
var hostingPlanName = appName
var storageAccountName = '${uniqueString(resourceGroup().id)}azfunctions'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
}

resource hostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: hostingPlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  tags: {
    'azd-service-name': 'func'
    test: 'test'
  }
  kind: 'functionapp,linux'
    identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uaResourceId}': {}
    }
  }
  properties: {
    virtualNetworkSubnetId: subnetId
    serverFarmId: hostingPlan.id
    reserved: true
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'AZURE_MSI_ID'
          value: uaClienId
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
        }
        {
          name: 'AZURE_OPENAI_SERVICE'
          value: azureOpenAiService
        }
        {
          name: 'AZURE_OPENAI_GPT_DEPLOYMENT'
          value: azureOpenAiGptDeployment
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      linuxFxVersion: 'Python|3.11'
      pythonVersion: '3.11'


      alwaysOn: true
    }
    httpsOnly: true
  }
}


output functionAppName string = functionApp.name
