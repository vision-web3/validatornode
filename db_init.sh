#!/bin/sh
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE "vision-validator-node" WITH LOGIN PASSWORD 'vision';
    CREATE DATABASE "vision-validator-node" WITH OWNER "vision-validator-node";
    CREATE DATABASE "vision-validator-node-celery" WITH OWNER "vision-validator-node";
    CREATE DATABASE "vision-validator-node-test" WITH OWNER "vision-validator-node";
EOSQL
