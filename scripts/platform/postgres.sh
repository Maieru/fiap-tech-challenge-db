#!/bin/sh
set -eu
psql --no-psqlrc --file=/scripts/postgres.sql
PGUSER=fiap_os PGPASSWORD="$OS_PASSWORD" PGDATABASE=fiap_os psql --no-psqlrc --command='SELECT 1' >/dev/null
PGUSER=fiap_billing PGPASSWORD="$BILLING_PASSWORD" PGDATABASE=fiap_billing psql --no-psqlrc --command='SELECT 1' >/dev/null
if PGUSER=fiap_os PGPASSWORD="$OS_PASSWORD" PGDATABASE=fiap_billing psql --no-psqlrc --command='SELECT 1' >/dev/null 2>/tmp/denied; then
  echo 'OS acessou o banco Billing.' >&2; exit 1
fi
grep -q 'permission denied for database' /tmp/denied
if PGUSER=fiap_billing PGPASSWORD="$BILLING_PASSWORD" PGDATABASE=fiap_os psql --no-psqlrc --command='SELECT 1' >/dev/null 2>/tmp/denied; then
  echo 'Billing acessou o banco OS.' >&2; exit 1
fi
grep -q 'permission denied for database' /tmp/denied
printf '%s\n' 'PostgreSQL inicializado e isolamento validado.'
