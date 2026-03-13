#!/usr/bin/env bash

set -euo pipefail

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is not installed or not in PATH." >&2
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "Error: You are not logged in. Run: az login" >&2
  exit 1
fi

required_vars=(
  RESOURCE_GROUP
  PRIMARY_LOCATION
  SECONDARY_LOCATION
  PRIMARY_SQL_SERVER_NAME
  SECONDARY_SQL_SERVER_NAME
  ENTRA_ADMIN_LOGIN
  ENTRA_ADMIN_OBJECT_ID
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Error: Required environment variable '${var_name}' is not set." >&2
    exit 1
  fi
done

PRIMARY_DATABASE_NAME="${PRIMARY_DATABASE_NAME:-appdb-primary}"
SECONDARY_DATABASE_NAME="${SECONDARY_DATABASE_NAME:-appdb-secondary}"
DATABASE_SKU_NAME="${DATABASE_SKU_NAME:-S0}"
DATABASE_SKU_TIER="${DATABASE_SKU_TIER:-Standard}"

echo "Ensuring resource group '${RESOURCE_GROUP}' exists in '${PRIMARY_LOCATION}'..."
az group create --name "${RESOURCE_GROUP}" --location "${PRIMARY_LOCATION}" >/dev/null

echo "Deploying Azure SQL servers and geo-replicated databases..."
az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "infra/main.bicep" \
  --parameters \
    primaryLocation="${PRIMARY_LOCATION}" \
    secondaryLocation="${SECONDARY_LOCATION}" \
    primarySqlServerName="${PRIMARY_SQL_SERVER_NAME}" \
    secondarySqlServerName="${SECONDARY_SQL_SERVER_NAME}" \
    entraAdminLogin="${ENTRA_ADMIN_LOGIN}" \
    entraAdminObjectId="${ENTRA_ADMIN_OBJECT_ID}" \
    primaryDatabaseName="${PRIMARY_DATABASE_NAME}" \
    secondaryDatabaseName="${SECONDARY_DATABASE_NAME}" \
    databaseSkuName="${DATABASE_SKU_NAME}" \
    databaseSkuTier="${DATABASE_SKU_TIER}"

echo "Deployment completed successfully."
