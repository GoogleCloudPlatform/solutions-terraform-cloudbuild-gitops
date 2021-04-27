#!/usr/bin/env bash

# Provisiona la vm poderosa de gcp para boaboa labs

# Upgrade de sistema operativo
apt update && apt dist-upgrade -y

# Instalar postgresql
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

apt-get update -y

apt-get -y install postgresql-12 postgresql-client-12