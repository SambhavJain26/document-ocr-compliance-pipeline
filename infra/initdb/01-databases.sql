-- PostgreSQL creates the COI application database from POSTGRES_DB.
-- Keep n8n's workflow and execution state in a separate database so demo
-- resets can never remove n8n configuration.
SELECT 'CREATE DATABASE n8n'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'n8n')\gexec
