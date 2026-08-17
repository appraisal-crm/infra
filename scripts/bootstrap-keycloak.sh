#!/usr/bin/env bash
set -e

echo "==> Waiting for Keycloak container (appraisal-keycloak) to be healthy..."
MAX_ATTEMPTS=30
ATTEMPT=0
until [ "$(docker inspect -f '{{.State.Health.Status}}' appraisal-keycloak 2>/dev/null)" = "healthy" ]; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "ERROR: Keycloak did not become healthy within timeout."
    exit 1
  fi
  echo "Waiting for Keycloak... ($ATTEMPT/$MAX_ATTEMPTS)"
  sleep 2
done

KC="docker exec appraisal-keycloak /opt/keycloak/bin/kcadm.sh"

echo "==> Authenticating kcadm as admin..."
$KC config credentials --server http://localhost:8080 --realm master --user admin --password admin

# Check if 'appraisal' realm already exists
if $KC get realms/appraisal >/dev/null 2>&1; then
  echo "==> Realm 'appraisal' already exists. Updating loginTheme..."
  $KC update realms/appraisal -s loginTheme=avangard >/dev/null 2>&1 || true
else
  echo "==> Creating realm 'appraisal' with avangard theme..."
  $KC create realms -s realm=appraisal -s enabled=true -s loginTheme=avangard
fi

# Ensure roles exist
echo "==> Ensuring roles (client, appraiser, inspector, admin) exist..."
for r in client appraiser inspector admin; do
  if ! $KC get roles/$r -r appraisal >/dev/null 2>&1; then
    $KC create roles -r appraisal -s name=$r
    echo "    Created role: $r"
  else
    echo "    Role $r already exists."
  fi
done

# Ensure client 'appraisal-frontend' exists
echo "==> Ensuring client 'appraisal-frontend' exists..."
CID=$($KC get clients -r appraisal -q clientId=appraisal-frontend --fields id --format csv --noquotes 2>/dev/null | tail -1 || true)
if [ -z "$CID" ]; then
  $KC create clients -r appraisal \
    -s clientId=appraisal-frontend \
    -s publicClient=true \
    -s directAccessGrantsEnabled=true \
    -s standardFlowEnabled=true \
    -s 'redirectUris=["http://localhost:5173/*","http://localhost:5174/*"]' \
    -s 'webOrigins=["http://localhost:5173","http://localhost:5174"]' \
    -s enabled=true
  echo "    Created client appraisal-frontend"
else
  $KC update clients/$CID -r appraisal \
    -s publicClient=true \
    -s directAccessGrantsEnabled=true \
    -s standardFlowEnabled=true \
    -s 'redirectUris=["http://localhost:5173/*","http://localhost:5174/*"]' \
    -s 'webOrigins=["http://localhost:5173","http://localhost:5174"]' \
    -s enabled=true >/dev/null 2>&1 || true
  echo "    Updated client appraisal-frontend"
fi

# Ensure test users exist
echo "==> Ensuring test users exist..."
USERS=("test-client:client" "test-appraiser:appraiser" "test-inspector:inspector" "test-admin:admin")
for entry in "${USERS[@]}"; do
  u="${entry%%:*}"
  role="${entry##*:}"
  
  if ! $KC get users -r appraisal -q username="$u" --fields id --format csv --noquotes 2>/dev/null | grep -q '^[a-z0-9-]'; then
    $KC create users -r appraisal -s username="$u" -s enabled=true \
      -s email="$u@example.com" -s firstName="Test" -s lastName="User" -s emailVerified=true
    $KC set-password -r appraisal --username "$u" --new-password test123
    $KC add-roles -r appraisal --uusername "$u" --rolename "$role"
    echo "    Created user $u with role $role (password: test123)"
  else
    echo "    User $u already exists."
  fi
done

echo "==> Keycloak setup complete!"
