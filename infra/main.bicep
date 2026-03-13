targetScope = 'resourceGroup'

@description('Azure region for the primary SQL logical server and database.')
param primaryLocation string = resourceGroup().location

@description('Azure region for the secondary SQL logical server and database.')
param secondaryLocation string

@description('Name of the primary Azure SQL logical server (global uniqueness required).')
param primarySqlServerName string

@description('Name of the secondary Azure SQL logical server (global uniqueness required).')
param secondarySqlServerName string

@description('Entra administrator login name (user, group, or service principal display name).')
param entraAdminLogin string

@description('Object ID (GUID) of the Entra administrator principal.')
param entraAdminObjectId string

@description('Name of the primary SQL database.')
param primaryDatabaseName string = 'appdb-primary'

@description('Name of the secondary SQL database (named replica).')
param secondaryDatabaseName string = 'appdb-secondary'

@description('SKU name for both primary and secondary SQL databases.')
param databaseSkuName string = 'S0'

@description('SKU tier for both primary and secondary SQL databases.')
param databaseSkuTier string = 'Standard'

module primarySqlServer './modules/sql-server-entra-auth.bicep' = {
  name: 'primary-sql-server-deployment'
  params: {
    location: primaryLocation
    sqlServerName: primarySqlServerName
    entraAdminLogin: entraAdminLogin
    entraAdminObjectId: entraAdminObjectId
  }
}

module secondarySqlServer './modules/sql-server-entra-auth.bicep' = {
  name: 'secondary-sql-server-deployment'
  params: {
    location: secondaryLocation
    sqlServerName: secondarySqlServerName
    entraAdminLogin: entraAdminLogin
    entraAdminObjectId: entraAdminObjectId
  }
}

module primaryDatabase './modules/sql-database-primary.bicep' = {
  name: 'primary-sql-database-deployment'
  params: {
    location: primaryLocation
    sqlServerName: primarySqlServer.outputs.sqlServerName
    databaseName: primaryDatabaseName
    databaseSkuName: databaseSkuName
    databaseSkuTier: databaseSkuTier
  }
}

module secondaryDatabase './modules/sql-database-geo-secondary.bicep' = {
  name: 'secondary-sql-database-deployment'
  params: {
    location: secondaryLocation
    sqlServerName: secondarySqlServer.outputs.sqlServerName
    databaseName: secondaryDatabaseName
    sourceDatabaseId: primaryDatabase.outputs.databaseId
    databaseSkuName: databaseSkuName
    databaseSkuTier: databaseSkuTier
  }
}

output primarySqlServerId string = primarySqlServer.outputs.sqlServerId
output primarySqlServerFqdn string = primarySqlServer.outputs.sqlServerFqdn
output secondarySqlServerId string = secondarySqlServer.outputs.sqlServerId
output secondarySqlServerFqdn string = secondarySqlServer.outputs.sqlServerFqdn
output primaryDatabaseId string = primaryDatabase.outputs.databaseId
output secondaryDatabaseId string = secondaryDatabase.outputs.databaseId
