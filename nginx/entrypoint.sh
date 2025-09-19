#!/usr/bin/env sh
set -eu

: "${SERVER_NAME:=wtcalc.example.com}"   # <— set your real subdomain
: "${UPSTREAM_HOST:=web}"                 # <— can be an IP like 203.0.113.42
: "${UPSTREAM_PORT:=3000}"
: "${REAL_IP_FROM:=}"

tpl="/etc/nginx/templates/default.conf.template"
out="/etc/nginx/conf.d/default.conf"

REAL_IP_BLOCK=""
if [ -n "$REAL_IP_FROM" ]; then
  REAL_IP_BLOCK="set_real_ip_from ${REAL_IP_FROM};\n  real_ip_header X-Forwarded-For;\n  real_ip_recursive on;"
fi

# Substitute upstream + server_name vars
envsubst '$SERVER_NAME $UPSTREAM_HOST $UPSTREAM_PORT' < "$tpl" > "$out"

# Inject/remove real_ip block
if [ -n "$REAL_IP_FROM" ]; then
  sed -i "s|__REAL_IP_BLOCK__|${REAL_IP_BLOCK}|g" "$out"
else
  sed -i "s|__REAL_IP_BLOCK__||g" "$out"
fi

echo "[nginx] server_name: ${SERVER_NAME}"
echo "[nginx] proxying to: ${UPSTREAM_HOST}:${UPSTREAM_PORT}"
[ -n "$REAL_IP_FROM" ] && echo "[nginx] trusting real IP from: ${REAL_IP_FROM}" || true

exec "$@"
