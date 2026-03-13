# Azure SQL Geo Named Replica (Bicep Modules)

Infrastructure-as-Code templates to deploy two Azure SQL logical servers and two SQL databases in an active geo-replication relationship using modular Bicep.

## Overview

This deployment creates:

- Primary Azure SQL logical server (Entra-only authentication)
- Secondary Azure SQL logical server (Entra-only authentication)
- Primary SQL database on the primary server
- Secondary SQL database (named replica) on the secondary server, linked via geo replication (`createMode: Secondary`)

## Architecture

```text
+------------------------------ Resource Group ---------------------------------+
|                                                                               |
|   +--------------------------+               +---------------------------+    |
|   | Primary SQL Server       |               | Secondary SQL Server      |    |
|   | (primary region)         |               | (secondary region)        |    |
|   +-------------+------------+               +-------------+-------------+    |
|                |                                           |                  |
|                v                                           v                  |
|    +-------------------------+               +----------------------------+   |
|    | Primary Database        | == Geo Rep => | Secondary Database         |   |
|    | appdb-primary           | <== Sync ===  | appdb-secondary (replica)  |   |
|    +-------------------------+               +----------------------------+   |
|                                                                               |
+-------------------------------------------------------------------------------+
```

## Repository Structure

- `deploy.sh`: Deploys using exported environment variables
- `infra/main.bicep`: Deployment entry point and module orchestration
- `infra/modules/sql-server-entra-auth.bicep`: Reusable Entra-only SQL logical server module
- `infra/modules/sql-database-primary.bicep`: Reusable primary SQL database module
- `infra/modules/sql-database-geo-secondary.bicep`: Reusable geo-secondary SQL database module
- `infra/main.parameters.json`: Example parameter values

## Prerequisites

- Azure subscription with permissions to deploy SQL resources
- Azure CLI installed and authenticated (`az login`)
- Existing or new resource group target

## Deployment

### Option 1: Deploy with exported environment variables (recommended)

1. Export required variables:

```bash
export RESOURCE_GROUP="rg-sql-geo-replica-dev"
export PRIMARY_LOCATION="uksouth"
export SECONDARY_LOCATION="ukwest"
export PRIMARY_SQL_SERVER_NAME="<globally-unique-primary-sql-server-name>"
export SECONDARY_SQL_SERVER_NAME="<globally-unique-secondary-sql-server-name>"
export ENTRA_ADMIN_LOGIN="<entra-admin-display-name>"
export ENTRA_ADMIN_OBJECT_ID="<entra-admin-object-id-guid>"
```

2. Export optional variables as needed:

```bash
export PRIMARY_DATABASE_NAME="appdb-primary"
export SECONDARY_DATABASE_NAME="appdb-secondary"
export DATABASE_SKU_NAME="S0"
export DATABASE_SKU_TIER="Standard"
```

3. Run the deployment script:

```bash
chmod +x deploy.sh
./deploy.sh
```

### Option 2: Deploy with parameter file

1. Update `infra/main.parameters.json`:
	- `primarySqlServerName` and `secondarySqlServerName` must be globally unique.
	- `entraAdminObjectId` must be a valid GUID value.
	- Choose supported SQL database SKU values for your subscription and region.

2. Create a resource group (if needed):

```bash
az group create --name <resource-group-name> --location <primary-region>
```

3. Deploy the templates:

```bash
az deployment group create \
	--resource-group <resource-group-name> \
	--template-file infra/main.bicep \
	--parameters @infra/main.parameters.json
```

## Key Parameters

- `primaryLocation`: Region for primary SQL server and primary database
- `secondaryLocation`: Region for secondary SQL server and geo-secondary database
- `primarySqlServerName`: Primary SQL logical server name (global uniqueness required)
- `secondarySqlServerName`: Secondary SQL logical server name (global uniqueness required)
- `entraAdminLogin` / `entraAdminObjectId`: Entra administrator identity for both SQL servers
- `primaryDatabaseName`: Primary SQL database name
- `secondaryDatabaseName`: Secondary SQL database name (named replica)
- `databaseSkuName` / `databaseSkuTier`: SKU configuration for both databases

For `deploy.sh`, these map to:

- `primaryLocation` -> `PRIMARY_LOCATION`
- `secondaryLocation` -> `SECONDARY_LOCATION`
- `primarySqlServerName` -> `PRIMARY_SQL_SERVER_NAME`
- `secondarySqlServerName` -> `SECONDARY_SQL_SERVER_NAME`
- `entraAdminLogin` -> `ENTRA_ADMIN_LOGIN`
- `entraAdminObjectId` -> `ENTRA_ADMIN_OBJECT_ID`
- `primaryDatabaseName` -> `PRIMARY_DATABASE_NAME`
- `secondaryDatabaseName` -> `SECONDARY_DATABASE_NAME`
- `databaseSkuName` -> `DATABASE_SKU_NAME`
- `databaseSkuTier` -> `DATABASE_SKU_TIER`

## Outputs

The deployment returns:

- Primary SQL server resource ID
- Primary SQL server FQDN
- Secondary SQL server resource ID
- Secondary SQL server FQDN
- Primary database resource ID
- Secondary database resource ID

## Operational Notes

- The secondary database is created with `createMode: Secondary`, which establishes geo replication from the primary database.
- Use regions that support your selected SQL SKU.
- Restrict network access and configure failover strategy based on production requirements.

## Failover

To promote the secondary replica to become the new primary, run failover against the **secondary** database resource.

Use the same environment variables from deployment:

```bash
export RESOURCE_GROUP="rg-sql-geo-replica-dev"
export SECONDARY_SQL_SERVER_NAME="<globally-unique-secondary-sql-server-name>"
export SECONDARY_DATABASE_NAME="appdb-secondary"
```

1. Planned failover (no data loss expected):

```bash
az sql db replica set-primary \
	--resource-group "$RESOURCE_GROUP" \
	--server "$SECONDARY_SQL_SERVER_NAME" \
	--name "$SECONDARY_DATABASE_NAME"
```

2. Forced failover (use only when the primary is unavailable; may lose recent writes):

```bash
az sql db replica set-primary \
	--resource-group "$RESOURCE_GROUP" \
	--server "$SECONDARY_SQL_SERVER_NAME" \
	--name "$SECONDARY_DATABASE_NAME" \
	--allow-data-loss
```

3. Verify replica roles and link status:

```bash
az sql db replica list-links \
	--resource-group "$RESOURCE_GROUP" \
	--server "$SECONDARY_SQL_SERVER_NAME" \
	--name "$SECONDARY_DATABASE_NAME" \
	--output table
```

### Post-failover considerations

- Update application connection strings to point at the new primary server FQDN.
- If required, re-establish geo replication in the opposite direction.
- In this repo defaults, `SECONDARY_DATABASE_NAME` is typically `appdb-secondary`.