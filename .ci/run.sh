#!/bin/bash
# This is intended to be run inside the docker container as the command of the docker-compose.

env

set -ex

export ACTIVEMQ_VERSION=5.15.9
./setup_broker.sh

jruby -rbundler/setup -S rspec -fd

./start_ssl_broker.sh
jruby -rbundler/setup -S rspec -fd --tag integration --tag tls --tag ~plaintext
./stop_broker.sh

./start_broker.sh
jruby -rbundler/setup -S rspec -fd --tag integration --tag plaintext --tag ~tls
./stop_broker.sh

./teardown_broker.sh
