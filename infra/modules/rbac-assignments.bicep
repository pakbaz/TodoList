// RBAC assignments module for managed identity permissions
targetScope = 'resourceGroup'

@description('Principal ID of the managed identity')
param principalId string

@description('Key Vault resource ID')
param keyVaultId string

@description('Container Registry resource ID')
param registryId string

@description('Role assignments to create')
param roleAssignments array = [
  {
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    resourceId: keyVaultId
    description: 'Key Vault Secrets User for Container App'
  }
  {
    roleDefinitionId: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
    resourceId: registryId
    description: 'ACR Pull for Container App'
  }
]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (assignment, index) in roleAssignments: {
  name: guid(assignment.resourceId, principalId, assignment.roleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
    description: assignment.description
  }
}]

// Outputs
output roleAssignmentIds array = [for (assignment, index) in roleAssignments: {
  roleDefinitionId: assignment.roleDefinitionId
  resourceId: assignment.resourceId
  assignmentId: roleAssignment[index].id
}]
