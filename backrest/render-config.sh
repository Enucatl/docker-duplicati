#!/bin/sh
set -eu

CONFIG_DIR=/config
CONFIG_PATH="$CONFIG_DIR/config.json"
CONFIG_HASH_PATH="$CONFIG_PATH.sha256"
TEMPLATE_PATH=/bootstrap/config.template.json
TMP_CONFIG_PATH="$CONFIG_PATH.tmp"
TMP_HASH_PATH="$CONFIG_HASH_PATH.tmp"

escape_sed() {
  printf '%s' "$1" | sed 's/[&|\\"]/\\&/g'
}

read_secret() {
  tr -d '\r\n' < "$1"
}

mkdir -p "$CONFIG_DIR"
umask 077

BACKREST_REPO_PASSWORD=$(read_secret /run/secrets/backrest_repo_password)
BACKREST_B2_ACCOUNT_ID=$(read_secret /run/secrets/backrest_b2_account_id)
BACKREST_B2_ACCOUNT_KEY=$(read_secret /run/secrets/backrest_b2_account_key)

sed \
  -e "s|__BACKREST_REPO_PASSWORD__|$(escape_sed "$BACKREST_REPO_PASSWORD")|g" \
  -e "s|__BACKREST_B2_ACCOUNT_ID__|$(escape_sed "$BACKREST_B2_ACCOUNT_ID")|g" \
  -e "s|__BACKREST_B2_ACCOUNT_KEY__|$(escape_sed "$BACKREST_B2_ACCOUNT_KEY")|g" \
  "$TEMPLATE_PATH" > "$TMP_CONFIG_PATH"

sha256sum "$TMP_CONFIG_PATH" | awk '{ print $1 }' > "$TMP_HASH_PATH"

if [ ! -f "$CONFIG_PATH" ] || [ ! -f "$CONFIG_HASH_PATH" ] || ! cmp -s "$TMP_HASH_PATH" "$CONFIG_HASH_PATH"; then
  mv "$TMP_CONFIG_PATH" "$CONFIG_PATH"
  mv "$TMP_HASH_PATH" "$CONFIG_HASH_PATH"
else
  rm -f "$TMP_CONFIG_PATH" "$TMP_HASH_PATH"
fi

exec /backrest
