#!/usr/bin/env bash
# Generate secrets for cluster deployment
# Usage: ./generate-secrets.sh <overlay-name>
#
# Generates random passwords for internal services.
# External credentials (AWS, AGE key) must be provided via environment variables.

set -euo pipefail

OVERLAY="${1:-etcdme-nbg1-dc3}"
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

# Check example file exists
if [[ ! -f "$EXAMPLE_FILE" ]]; then
  echo -e "${RED}Error: Example file not found: ${EXAMPLE_FILE}${NC}"
  exit 1
fi

echo -e "${YELLOW}Generating secrets for overlay: ${OVERLAY}${NC}"
echo ""

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
sed -i "s|client-secret: REPLACE_UPTIME_KUMA_CLIENT_SECRET|client-secret: ${UPTIME_KUMA_CLIENT_SECRET}|g" "$SECRETS_FILE"
sed -i "s|cookie-secret: REPLACE_UPTIME_KUMA_COOKIE_SECRET|cookie-secret: ${UPTIME_KUMA_COOKIE_SECRET}|" "$SECRETS_FILE"

echo -e "${GREEN}Secrets file created: ${SECRETS_FILE}${NC}"
echo ""

# Encrypt with SOPS
echo -e "${YELLOW}Encrypting with SOPS...${NC}"
sops -e -i "$SECRETS_FILE"

echo ""
echo -e "${GREEN}Done! Encrypted secrets file ready.${NC}"
echo ""
echo "Next steps:"
echo "  1. Commit: git add ${SECRETS_FILE} && git commit -m 'feat: add encrypted secrets'"
echo "  2. Deploy: task argocd:bootstrap"
