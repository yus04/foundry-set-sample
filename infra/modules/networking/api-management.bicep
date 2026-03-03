// ============================================
// API Management - AI Gateway
// ============================================

@description('Azure region for API Management')
param location string

@description('API Management service name')
param apimName string

@description('Tags to apply to resources')
param tags object = {}

@description('AI Services account endpoint')
param aiAccountEndpoint string

@description('Publisher email for APIM')
param publisherEmail string

@description('Publisher name for APIM')
param publisherName string

// ============================================
// API Management Service
// ============================================

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// ============================================
// Backend - Foundry AI Services
// ============================================

resource aiBackend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: 'foundry-ai-backend'
  properties: {
    protocol: 'http'
    url: aiAccountEndpoint
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// ============================================
// API - Azure OpenAI
// ============================================

resource openAiApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'azure-openai-api'
  properties: {
    displayName: 'Azure OpenAI API'
    path: 'openai'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    serviceUrl: '${aiAccountEndpoint}openai'
    apiType: 'http'
  }
}

// Chat Completions Operation
resource chatCompletionsOp 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: openAiApi
  name: 'chat-completions'
  properties: {
    displayName: 'Chat Completions'
    method: 'POST'
    urlTemplate: '/deployments/{deployment-id}/chat/completions?api-version={api-version}'
    templateParameters: [
      {
        name: 'deployment-id'
        type: 'string'
        required: true
      }
      {
        name: 'api-version'
        type: 'string'
        required: true
      }
    ]
  }
}

// Completions Operation
resource completionsOp 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: openAiApi
  name: 'completions'
  properties: {
    displayName: 'Completions'
    method: 'POST'
    urlTemplate: '/deployments/{deployment-id}/completions?api-version={api-version}'
    templateParameters: [
      {
        name: 'deployment-id'
        type: 'string'
        required: true
      }
      {
        name: 'api-version'
        type: 'string'
        required: true
      }
    ]
  }
}

// Embeddings Operation
resource embeddingsOp 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: openAiApi
  name: 'embeddings'
  properties: {
    displayName: 'Embeddings'
    method: 'POST'
    urlTemplate: '/deployments/{deployment-id}/embeddings?api-version={api-version}'
    templateParameters: [
      {
        name: 'deployment-id'
        type: 'string'
        required: true
      }
      {
        name: 'api-version'
        type: 'string'
        required: true
      }
    ]
  }
}

// ============================================
// AI Gateway Policy
// ============================================

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: openAiApi
  name: 'policy'
  properties: {
    format: 'xml'
    value: '''<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="foundry-ai-backend" />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com/" />
    <azure-openai-token-limit
      counter-key="@(context.Subscription.Id)"
      tokens-per-minute="100000"
      estimate-prompt-tokens="true"
      remaining-tokens-variable-name="remainingTokens" />
    <azure-openai-emit-token-metric namespace="AzureOpenAI">
      <dimension name="Subscription ID" />
      <dimension name="API ID" />
    </azure-openai-emit-token-metric>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>'''
  }
  dependsOn: [
    aiBackend
  ]
}

// ============================================
// Outputs
// ============================================

output apimId string = apim.id
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimPrincipalId string = apim.identity.principalId
