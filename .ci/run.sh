#!/bin/bash
# This is intended to be run inside the docker container as the command of the docker-compose.

env

set -ex

export ACTIVEMQ_VERSION=5.15.16
./setup_broker.sh
bundle install

java_major_version="$(JRUBY_OPTS="" jruby -e 'puts ENV_JAVA["java.version"]&.slice(/(?!1[.])[0-9]+/)')"
if (( "${java_major_version}" >= "9" )); then
  export JRUBY_OPTS="-J--add-exports=java.base/sun.security.ssl=ALL-UNNAMED${JRUBY_OPTS:+ }${JRUBY_OPTS}"
fi

bundle exec rspec

./start_ssl_broker.sh
bundle exec rspec -fd --tag integration --tag tls --tag ~plaintext
./stop_broker.sh

./start_broker.sh
bundle exec rspec -fd --tag integration --tag plaintext --tag ~tls
./stop_broker.sh

./teardown_broker.sh
