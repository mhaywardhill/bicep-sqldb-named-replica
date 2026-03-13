@description('Azure region for the geo-secondary SQL database.')
param location string

@description('Name of the Azure SQL logical server that hosts the geo-secondary database.')
param sqlServerName string

@description('Name of the geo-secondary SQL database.')
param databaseName string

@description('Resource ID of the source (primary) SQL database.')
param sourceDatabaseId string

@description('SKU name for the geo-secondary SQL database.')
param databaseSkuName string

@description('SKU tier for the geo-secondary SQL database.')
param databaseSkuTier string

resource geoSecondaryDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  name: '${sqlServerName}/${databaseName}'
  location: location
  sku: {
    name: databaseSkuName
    tier: databaseSkuTier
  }
  properties: {
    createMode: 'Secondary'
    sourceDatabaseId: sourceDatabaseId
    secondaryType: 'Geo'
  }
}

output databaseId string = geoSecondaryDatabase.id
output databaseName string = geoSecondaryDatabase.name
