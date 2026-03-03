#!/usr/bin/env bash
# Generate an Android release keystore and output the GitHub Secrets values.
# Usage: bash scripts/setup-signing.sh

set -euo pipefail

KEYSTORE_FILE="numi-release.jks"
KEY_ALIAS="numi"
VALIDITY_DAYS=10000

if [ -f "$KEYSTORE_FILE" ]; then
  echo "Keystore $KEYSTORE_FILE already exists. Remove it first if you want to regenerate."
  exit 1
fi

echo "=== Generating Android Release Keystore ==="
echo ""

read -sp "Enter keystore password (min 6 chars): " STORE_PASSWORD
echo ""
read -sp "Confirm keystore password: " STORE_PASSWORD_CONFIRM
echo ""

if [ "$STORE_PASSWORD" != "$STORE_PASSWORD_CONFIRM" ]; then
  echo "ERROR: Passwords don't match."
  exit 1
fi

if [ ${#STORE_PASSWORD} -lt 6 ]; then
  echo "ERROR: Password must be at least 6 characters."
  exit 1
fi

keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE_FILE" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$STORE_PASSWORD" \
  -dname "CN=Numi Finance, O=Steaunk"

echo ""
echo "=== Keystore generated: $KEYSTORE_FILE ==="
echo ""
echo "Now add these 4 GitHub Secrets to your repository:"
echo "  https://github.com/Steaunk/numi-finance/settings/secrets/actions"
echo ""
echo "1) KEYSTORE_BASE64:"
echo "---"
base64 -i "$KEYSTORE_FILE"
echo "---"
echo ""
echo "2) KEY_ALIAS:       $KEY_ALIAS"
echo "3) KEY_PASSWORD:     $STORE_PASSWORD"
echo "4) STORE_PASSWORD:   $STORE_PASSWORD"
echo ""
echo "IMPORTANT: Keep $KEYSTORE_FILE safe! If lost, you cannot update the app."
echo "           Consider backing it up securely (NOT in git)."
