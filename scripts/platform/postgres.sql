\set ON_ERROR_STOP on
\getenv os_password OS_PASSWORD
\getenv billing_password BILLING_PASSWORD
SELECT format('CREATE ROLE %I LOGIN', 'fiap_os') WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fiap_os') \gexec
SELECT format('CREATE ROLE %I LOGIN', 'fiap_billing') WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fiap_billing') \gexec
ALTER ROLE fiap_os NOCREATEDB NOCREATEROLE LOGIN PASSWORD :'os_password';
ALTER ROLE fiap_billing NOCREATEDB NOCREATEROLE LOGIN PASSWORD :'billing_password';
DO $privileges$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('fiap_os', 'fiap_billing') AND (rolsuper OR rolcreatedb OR rolcreaterole)) THEN
    RAISE EXCEPTION 'Application roles have administrative privileges';
  END IF;
END $privileges$;
GRANT fiap_os, fiap_billing TO fiap_admin;
SELECT format('CREATE DATABASE %I OWNER %I', 'fiap_os', 'fiap_os') WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'fiap_os') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', 'fiap_billing', 'fiap_billing') WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'fiap_billing') \gexec
REVOKE ALL ON DATABASE fiap_os FROM PUBLIC;
REVOKE ALL ON DATABASE fiap_billing FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE fiap_os TO fiap_os;
GRANT CONNECT, TEMPORARY ON DATABASE fiap_billing TO fiap_billing;
\connect fiap_os
REVOKE ALL ON SCHEMA public FROM PUBLIC;
ALTER SCHEMA public OWNER TO fiap_os;
\connect fiap_billing
REVOKE ALL ON SCHEMA public FROM PUBLIC;
ALTER SCHEMA public OWNER TO fiap_billing;
