targetScope = 'subscription'

param rgName string
param rgLocation string

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: rgLocation
}