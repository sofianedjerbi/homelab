#!/usr/bin/env bash
# Generate secrets for cluster deployment
# Usage: ./generate-secrets.sh [--update] <overlay-name>
#
# Modes:
#   (default)  Generate all secrets from scratch (regenerates passwords)
#   --update   Update existing secrets file - adds new secrets without regenerating existing ones
#
# External credentials read from .env:
#   - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_HOSTED_ZONE_ID
#   - SOPS_AGE_KEY
#   - S3_BACKUP_ENDPOINT, S3_BACKUP_BUCKET, S3_BACKUP_ACCESS_KEY_ID, S3_BACKUP_SECRET_ACCESS_KEY (optional)

set -euo pipefail

# Parse arguments
UPDATE_MODE=false
OVERLAY="etcdme-nbg1-dc3"

while [[ $# -gt 0 ]]; do
  case $1 in
    --update)
      UPDATE_MODE=true
      shift
      ;;
    *)
      OVERLAY="$1"
      shift
      ;;
  esac
done

SECRETS_FILE="argocd/overlays/${OVERLAY}/secrets.sops.yaml"
EXAMPLE_FILE="argocd/overlays/${OVERLAY}/secrets.example.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Generate random password (32 chars, alphanumeric)
gen_password() {
  openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
}

echo -e "${GREEN}=== Cluster Secrets Generator ===${NC}"
echo ""

# Check required external variables
missing_vars=()
[[ -z "${AWS_ACCESS_KEY_ID:-}" ]] && missing_vars+=("AWS_ACCESS_KEY_ID")
[[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]] && missing_vars+=("AWS_SECRET_ACCESS_KEY")
[[ -z "${AWS_HOSTED_ZONE_ID:-}" ]] && missing_vars+=("AWS_HOSTED_ZONE_ID")
[[ -z "${SOPS_AGE_KEY:-}" ]] && missing_vars+=("SOPS_AGE_KEY")

if [[ ${#missing_vars[@]} -gt 0 ]]; then
  echo -e "${RED}Error: Missing required environment variables:${NC}"
  for var in "${missing_vars[@]}"; do
    echo "  - $var"
  done
  echo ""
  echo "Configure these in .env (see .env.example)"
  exit 1
fi

# UPDATE MODE: Decrypt existing, add new secrets, re-encrypt
if [[ "$UPDATE_MODE" == true ]]; then
  echo -e "${YELLOW}Update mode: preserving existing secrets${NC}"
  echo ""

  if [[ ! -f "$SECRETS_FILE" ]]; then
    echo -e "${RED}Error: Secrets file not found: ${SECRETS_FILE}${NC}"
    echo "Use without --update to generate from scratch"
    exit 1
  fi

  # Decrypt in place
  echo "Decrypting existing secrets..."
  sops -d -i "$SECRETS_FILE"

  # Add S3 backup secret if configured and not already present
  if [[ -n "${S3_BACKUP_ACCESS_KEY_ID:-}" ]] && [[ -n "${S3_BACKUP_SECRET_ACCESS_KEY:-}" ]]; then
    if ! grep -q "name: s3-backup-credentials" "$SECRETS_FILE"; then
      echo "Adding S3 backup credentials..."
      cat >> "$SECRETS_FILE" << EOF
---
# S3 backup credentials for PostgreSQL CNPG backups
apiVersion: v1
kind: Secret
metadata:
  name: s3-backup-credentials
  namespace: postgres
type: Opaque
stringData:
  ACCESS_KEY_ID: ${S3_BACKUP_ACCESS_KEY_ID}
  ACCESS_SECRET_KEY: ${S3_BACKUP_SECRET_ACCESS_KEY}
EOF
      echo "  - Added s3-backup-credentials"
    else
      echo "  - s3-backup-credentials already exists, updating..."
      # Use perl for multi-line replacement
      perl -i -0pe "s/(name: s3-backup-credentials.*?ACCESS_KEY_ID: )[^\n]*/\${1}${S3_BACKUP_ACCESS_KEY_ID}/s" "$SECRETS_FILE"
      perl -i -0pe "s/(name: s3-backup-credentials.*?ACCESS_SECRET_KEY: )[^\n]*/\${1}${S3_BACKUP_SECRET_ACCESS_KEY}/s" "$SECRETS_FILE"
    fi
  fi

  # Update Filestash S3 credentials if configured
  if [[ -n "${FILESTASH_S3_ENDPOINT:-}" ]]; then
    if grep -q "name: filestash-config" "$SECRETS_FILE"; then
      echo "Updating Filestash S3 credentials..."
      # Escape special chars for perl regex replacement
      s3_endpoint_escaped="${FILESTASH_S3_ENDPOINT//\//\\/}"
      s3_region="${FILESTASH_S3_REGION:-us-east-1}"
      perl -i -0pe "s/(name: filestash-config.*?s3-endpoint: )[^\n]*/\${1}${s3_endpoint_escaped}/s" "$SECRETS_FILE"
      perl -i -0pe "s/(name: filestash-config.*?s3-access-key: )[^\n]*/\${1}${FILESTASH_S3_ACCESS_KEY}/s" "$SECRETS_FILE"
      perl -i -0pe "s/(name: filestash-config.*?s3-secret-key: )[^\n]*/\${1}${FILESTASH_S3_SECRET_KEY}/s" "$SECRETS_FILE"
      perl -i -0pe "s/(name: filestash-config.*?s3-bucket: )[^\n]*/\${1}${FILESTASH_S3_BUCKET}/s" "$SECRETS_FILE"
      perl -i -0pe "s/(name: filestash-config.*?s3-region: )[^\n]*/\${1}${s3_region}/s" "$SECRETS_FILE"
      echo "  - Updated filestash-config S3 credentials"
    fi
  fi

  # Compare example file to find missing secrets and add them
  if [[ -f "$EXAMPLE_FILE" ]]; then
    echo "Checking for new secrets in example file..."

    # Extract all secret names from example file (handles indentation)
    example_secrets=$(grep -E "^\s*name:" "$EXAMPLE_FILE" | grep -v "app.kubernetes.io" | sed 's/.*name:\s*//' | sort -u)

    for secret_name in $example_secrets; do
      if ! grep -q "name: ${secret_name}$" "$SECRETS_FILE"; then
        echo "  - Adding missing secret: $secret_name"

        # Extract the YAML block for this secret using awk
        # Looks for blocks starting with "apiVersion:" or "---" and containing "name: $secret_name"
        secret_block=$(awk -v target="$secret_name" '
          BEGIN { collecting=0; block="" }
          /^---$/ || /^apiVersion:/ {
            if (collecting && found) { print block }
            block = (/^---$/) ? "" : $0 "\n"
            collecting = 1
            found = 0
            next
          }
          collecting {
            block = block $0 "\n"
            if ($0 ~ "name: " target "$") { found = 1 }
          }
          END { if (collecting && found) print block }
        ' "$EXAMPLE_FILE")

        # Replace placeholder passwords with generated ones (or reuse existing values)
        if [[ -n "$secret_block" ]]; then
          modified_block="$secret_block"

          # Find all unique REPLACE_ placeholders and replace each with a unique password
          # Note: pattern includes digits for placeholders like S3_ENDPOINT
          placeholders=$(echo "$modified_block" | grep -oE 'REPLACE_[A-Z0-9_]+' | sort -ru)
          for placeholder in $placeholders; do
            # Check if this placeholder value already exists in the secrets file
            # This ensures shared secrets (like client-secret used by multiple resources) stay consistent
            existing_value=""
            case "$placeholder" in
              REPLACE_FILESTASH_CLIENT_SECRET)
                existing_value=$(grep -A1 "name: filestash-client-secret" "$SECRETS_FILE" | grep "client-secret:" | sed 's/.*client-secret: //' | head -1)
                ;;
              REPLACE_N8N_CLIENT_SECRET)
                existing_value=$(grep -A1 "name: n8n-client-secret" "$SECRETS_FILE" | grep "client-secret:" | sed 's/.*client-secret: //' | head -1)
                ;;
              REPLACE_UPTIME_KUMA_CLIENT_SECRET)
                existing_value=$(grep -A1 "name: uptime-kuma-client-secret" "$SECRETS_FILE" | grep "client-secret:" | sed 's/.*client-secret: //' | head -1)
                ;;
            esac

            if [[ -n "$existing_value" && "$existing_value" != "REPLACE_"* ]]; then
              modified_block="${modified_block//$placeholder/$existing_value}"
              echo "    (reusing existing value for $placeholder)"
            else
              new_password=$(gen_password)
              modified_block="${modified_block//$placeholder/$new_password}"
            fi
          done

          echo "---" >> "$SECRETS_FILE"
          printf "%s" "$modified_block" >> "$SECRETS_FILE"
        fi
      fi
    done
  fi

  echo ""

# FULL GENERATION MODE
else
  echo -e "${YELLOW}Full generation mode: creating new secrets${NC}"
  echo ""

  # Check example file exists
  if [[ ! -f "$EXAMPLE_FILE" ]]; then
    echo -e "${RED}Error: Example file not found: ${EXAMPLE_FILE}${NC}"
    exit 1
  fi

  # Generate random secrets
  KEYCLOAK_DB_PASSWORD=$(gen_password)
  GRAFANA_ADMIN_PASSWORD=$(gen_password)
  ARGOCD_SERVER_SECRET=$(gen_password)
  N8N_CLIENT_SECRET=$(gen_password)
  N8N_COOKIE_SECRET=$(gen_password)
  N8N_DB_PASSWORD=$(gen_password)
  N8N_ENCRYPTION_KEY=$(gen_password)
  UPTIME_KUMA_CLIENT_SECRET=$(gen_password)
  UPTIME_KUMA_COOKIE_SECRET=$(gen_password)
  UPTIME_KUMA_ADMIN_PASSWORD=$(gen_password)
  PLAYWRIGHT_MCP_TOKEN=$(gen_password)
  FILESTASH_CLIENT_SECRET=$(gen_password)
  FILESTASH_SECRET_KEY=$(gen_password)
  FILESTASH_ADMIN_PASSWORD=$(gen_password)
  FILESTASH_COOKIE_SECRET=$(gen_password)

  echo "Generated passwords:"
  echo "  - Keycloak DB password"
  echo "  - Grafana admin password"
  echo "  - ArgoCD server secret key"
  echo "  - n8n OAuth client secret"
  echo "  - n8n cookie secret"
  echo "  - n8n DB password"
  echo "  - n8n encryption key"
  echo "  - Uptime Kuma OAuth client secret"
  echo "  - Uptime Kuma cookie secret"
  echo "  - Uptime Kuma admin password"
  echo "  - Playwright MCP token"
  echo "  - Filestash client secret"
  echo "  - Filestash secret key"
  echo "  - Filestash admin password"
  echo "  - Filestash cookie secret"
  echo ""

  # Copy example and replace values
  cp "$EXAMPLE_FILE" "$SECRETS_FILE"

  # Replace external (AWS + AGE)
  sed -i "s|access-key-id: REPLACE_ME|access-key-id: ${AWS_ACCESS_KEY_ID}|" "$SECRETS_FILE"
  sed -i "s|secret-access-key: REPLACE_ME|secret-access-key: ${AWS_SECRET_ACCESS_KEY}|" "$SECRETS_FILE"
  sed -i "s|hosted-zone-id: REPLACE_ME|hosted-zone-id: ${AWS_HOSTED_ZONE_ID}|" "$SECRETS_FILE"
  sed -i "s|# AGE-SECRET-KEY-REPLACE_ME|${SOPS_AGE_KEY}|" "$SECRETS_FILE"

  # Replace generated secrets
  # Keycloak DB
  sed -i "s|db-password: REPLACE_ME|db-password: ${KEYCLOAK_DB_PASSWORD}|" "$SECRETS_FILE"

  # Postgres (must match keycloak db-password)
  sed -i "0,/password: REPLACE_ME/s|password: REPLACE_ME|password: ${KEYCLOAK_DB_PASSWORD}|" "$SECRETS_FILE"

  # Grafana admin
  sed -i "s|admin-password: REPLACE_ME|admin-password: ${GRAFANA_ADMIN_PASSWORD}|" "$SECRETS_FILE"

  # ArgoCD server secret
  sed -i "s|server.secretkey: REPLACE_ME|server.secretkey: ${ARGOCD_SERVER_SECRET}|" "$SECRETS_FILE"

  # n8n secrets
  sed -i "s|client-secret: REPLACE_N8N_CLIENT_SECRET|client-secret: ${N8N_CLIENT_SECRET}|g" "$SECRETS_FILE"
  sed -i "s|cookie-secret: REPLACE_N8N_COOKIE_SECRET|cookie-secret: ${N8N_COOKIE_SECRET}|" "$SECRETS_FILE"
  sed -i "s|DB_POSTGRESDB_PASSWORD: REPLACE_N8N_DB_PASSWORD|DB_POSTGRESDB_PASSWORD: ${N8N_DB_PASSWORD}|" "$SECRETS_FILE"
  sed -i "s|password: REPLACE_N8N_DB_PASSWORD|password: ${N8N_DB_PASSWORD}|" "$SECRETS_FILE"
  sed -i "s|N8N_ENCRYPTION_KEY: REPLACE_N8N_ENCRYPTION_KEY|N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}|" "$SECRETS_FILE"

  # Uptime Kuma secrets
  sed -i "s|password: REPLACE_UPTIME_KUMA_ADMIN_PASSWORD|password: ${UPTIME_KUMA_ADMIN_PASSWORD}|" "$SECRETS_FILE"
  sed -i "s|client-secret: REPLACE_UPTIME_KUMA_CLIENT_SECRET|client-secret: ${UPTIME_KUMA_CLIENT_SECRET}|g" "$SECRETS_FILE"
  sed -i "s|cookie-secret: REPLACE_UPTIME_KUMA_COOKIE_SECRET|cookie-secret: ${UPTIME_KUMA_COOKIE_SECRET}|" "$SECRETS_FILE"

  # S3 Backup credentials (optional - only if configured in .env)
  if [[ -n "${S3_BACKUP_ACCESS_KEY_ID:-}" ]] && [[ -n "${S3_BACKUP_SECRET_ACCESS_KEY:-}" ]]; then
    sed -i "s|ACCESS_KEY_ID: REPLACE_S3_BACKUP_ACCESS_KEY|ACCESS_KEY_ID: ${S3_BACKUP_ACCESS_KEY_ID}|" "$SECRETS_FILE"
    sed -i "s|ACCESS_SECRET_KEY: REPLACE_S3_BACKUP_SECRET_KEY|ACCESS_SECRET_KEY: ${S3_BACKUP_SECRET_ACCESS_KEY}|" "$SECRETS_FILE"
    echo "  - S3 backup credentials"
  fi

  # Playwright MCP token
  sed -i "s|token: REPLACE_PLAYWRIGHT_MCP_TOKEN|token: ${PLAYWRIGHT_MCP_TOKEN}|" "$SECRETS_FILE"

  # Filestash secrets
  sed -i "s|client-secret: REPLACE_FILESTASH_CLIENT_SECRET|client-secret: ${FILESTASH_CLIENT_SECRET}|g" "$SECRETS_FILE"
  sed -i "s|oidc-client-secret: REPLACE_FILESTASH_CLIENT_SECRET|oidc-client-secret: ${FILESTASH_CLIENT_SECRET}|" "$SECRETS_FILE"
  sed -i "s|secret-key: REPLACE_FILESTASH_SECRET_KEY|secret-key: ${FILESTASH_SECRET_KEY}|" "$SECRETS_FILE"
  sed -i "s|admin-password: REPLACE_FILESTASH_ADMIN_PASSWORD|admin-password: ${FILESTASH_ADMIN_PASSWORD}|" "$SECRETS_FILE"
  sed -i "s|cookie-secret: REPLACE_FILESTASH_COOKIE_SECRET|cookie-secret: ${FILESTASH_COOKIE_SECRET}|" "$SECRETS_FILE"

  # Filestash S3 backend (optional - from .env)
  if [[ -n "${FILESTASH_S3_ENDPOINT:-}" ]]; then
    sed -i "s|s3-endpoint: REPLACE_FILESTASH_S3_ENDPOINT|s3-endpoint: ${FILESTASH_S3_ENDPOINT}|" "$SECRETS_FILE"
    sed -i "s|s3-access-key: REPLACE_FILESTASH_S3_ACCESS_KEY|s3-access-key: ${FILESTASH_S3_ACCESS_KEY}|" "$SECRETS_FILE"
    sed -i "s|s3-secret-key: REPLACE_FILESTASH_S3_SECRET_KEY|s3-secret-key: ${FILESTASH_S3_SECRET_KEY}|" "$SECRETS_FILE"
    sed -i "s|s3-bucket: REPLACE_FILESTASH_S3_BUCKET|s3-bucket: ${FILESTASH_S3_BUCKET}|" "$SECRETS_FILE"
    sed -i "s|s3-region: REPLACE_FILESTASH_S3_REGION|s3-region: ${FILESTASH_S3_REGION:-us-east-1}|" "$SECRETS_FILE"
    echo "  - Filestash S3 backend"
  fi
fi

echo -e "${GREEN}Secrets file updated: ${SECRETS_FILE}${NC}"
echo ""

# Update cluster.yaml with S3 backup endpoint/bucket (if configured)
CLUSTER_FILE="argocd/base/resources/postgres/cluster.yaml"
if [[ -n "${S3_BACKUP_ENDPOINT:-}" ]] && [[ -n "${S3_BACKUP_BUCKET:-}" ]]; then
  if [[ -f "$CLUSTER_FILE" ]]; then
    echo -e "${YELLOW}Updating cluster.yaml with S3 backup config...${NC}"
    sed -i "s|S3_ENDPOINT_PLACEHOLDER|${S3_BACKUP_ENDPOINT}|g" "$CLUSTER_FILE"
    sed -i "s|S3_BUCKET_PLACEHOLDER|${S3_BACKUP_BUCKET}|g" "$CLUSTER_FILE"
    echo "  - Updated S3 endpoint: ${S3_BACKUP_ENDPOINT}"
    echo "  - Updated S3 bucket: ${S3_BACKUP_BUCKET}"
    echo ""
  fi
fi

# Encrypt with SOPS
echo -e "${YELLOW}Encrypting with SOPS...${NC}"
sops -e -i "$SECRETS_FILE"

echo ""
echo -e "${GREEN}Done! Encrypted secrets file ready.${NC}"
echo ""
echo "Next steps:"
echo "  1. Commit: git add ${SECRETS_FILE} ${CLUSTER_FILE} && git commit -m 'feat: add S3 backup config'"
echo "  2. Push and let ArgoCD sync"
