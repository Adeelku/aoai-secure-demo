targetScope = 'subscription'


// GenAI MTL Params
param disableLocalAuth bool = true
param applyRbac bool = true
param useNetIsolation bool = true
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'
param deployVm bool = false

// End

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string


param publicKey string

@minLength(1)
@description('Location for the OpenAI resource')
// https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models#standard-deployment-model-availability
@allowed([
  'australiaeast'
  'brazilsouth'
  'canadaeast'
  'eastus'
  'eastus2'
  'francecentral'
  'japaneast'
  'northcentralus'
  'norwayeast'
  'southafricanorth'
  'southcentralus'
  'southindia'
  'swedencentral'
  'switzerlandnorth'
  'uksouth'
  'westeurope'
  'westus'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

@description('Name of the OpenAI resource group. If not specified, the resource group name will be generated.')
param openAiResourceGroupName string = ''

@description('Name of the GPT model to deploy')
param gptModelName string = 'gpt-35-turbo'

@description('Version of the GPT model to deploy')
// See version availability in this table:
// https://learn.microsoft.com/azure/ai-services/openai/concepts/models#gpt-4-and-gpt-4-turbo-preview-models
param gptModelVersion string = '0613'

@description('Name of the model deployment')
param gptDeploymentName string = 'mygptdeployment'

@description('Capacity of the GPT deployment')
// You can increase this, but capacity is limited per model/region, so you will get errors if you go over
// https://learn.microsoft.com/en-us/azure/ai-services/openai/quotas-limits
param gptDeploymentCapacity int = 30

@description('Id of the user or app to assign application roles')
param principalId string = ''

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var prefix = '${environmentName}-${resourceToken}'
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' =
  if (empty(openAiResourceGroupName)) {
    name: '${prefix}-rg'
    location: location
    tags: tags
  }

resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' existing =
  if (!empty(openAiResourceGroupName)) {
    name: !empty(openAiResourceGroupName) ? openAiResourceGroupName : resourceGroup.name
  }


  module vnetModule 'core/network/vnet.bicep' = if (useNetIsolation){
  name: 'vnet'
  scope: openAiResourceGroup
  params: {
    vnetName: '${prefix}-vnet'
    location: location
    addressPrefix: '10.0.0.0/16'
    subnets: [
      {
        name: 'default'
        addressPrefix: '10.0.1.0/24'
        delegation: ''
      }
      {
        name: 'privateendpoints'
        addressPrefix: '10.0.2.0/24'
        delegation: ''
      }
            {
        name: 'webapp'
        addressPrefix: '10.0.3.0/28'
        delegation: 'Microsoft.Web/serverFarms'

      }
    ]
  }
}

module openAi 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: '${prefix}-openai'
    location: location
    tags: tags
    publicNetworkAccess: publicNetworkAccess
    subnetID: useNetIsolation ? vnetModule.outputs.PrivateEndPointId : ''
    useNetIsolation: useNetIsolation
    privateDnsZoneId: useNetIsolation ? vnetModule.outputs.privateDnsZoneId : ''
    sku: {
      name: 'S0'
    }
    disableLocalAuth: disableLocalAuth
    deployments: [
      {
        name: gptDeploymentName
        model: {
          format: 'OpenAI'
          name: gptModelName
          version: gptModelVersion
        }
        sku: {
          name: 'Standard'
          capacity: gptDeploymentCapacity
        }
      }
    ]
  }
}

// USER ROLES
module openAiRoleUser 'core/security/role.bicep' = if (applyRbac) {
  scope: openAiResourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'User'
  }
}

module uma 'core/iam/managedidentity.bicep' = {
  scope: openAiResourceGroup
  name: 'create-${prefix}-uma'
  params: {
    name: '${prefix}-uma'
    location: location
  }
}


// Managed identity role
module openAiRoleUMA 'core/security/role.bicep' =  {
  scope: openAiResourceGroup
  name: 'openai-role-uma'
  params: {
    principalId: uma.outputs.uaPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}



module createVm 'core/compute/vm.bicep' = if (deployVm) {
  scope: openAiResourceGroup
  name: 'createLinuxVM'
  params: {
    vmName: 'outter-rim-vm'
    location: location
    subnetID: (useNetIsolation) && (deployVm) ? vnetModule.outputs.defaultId : ''
    publicKey: publicKey
  }
}


module CreateFunc 'core/func/func.bicep' = {
  scope: openAiResourceGroup
  name: 'Create-${prefix}-func'
  params: {
    appName: '${prefix}-func'
    subnetId: useNetIsolation ? vnetModule.outputs.webID : ''
    location: location
    uaResourceId: uma.outputs.uaID
    uaClienId: uma.outputs.uaClientId
    azureOpenAiGptDeployment: gptDeploymentName
    azureOpenAiService: openAi.outputs.name
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name

// Specific to Azure OpenAI
output AZURE_OPENAI_SERVICE string = openAi.outputs.name
output AZURE_OPENAI_GPT_MODEL string = gptModelName
output AZURE_OPENAI_GPT_DEPLOYMENT string = gptDeploymentName
output AZURE_MSI_ID string = uma.outputs.uaClientId
output AZURE_FUNC_NAME string = CreateFunc.outputs.functionAppName


