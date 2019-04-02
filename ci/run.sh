#!/bin/bash
export ACTIVEMQ_VERSION=5.15.9
./setup_broker.sh
bundle install
bundle exec rspec
./start_ssl_broker.sh
bundle exec rspec -fd --tag integration --tag tls --tag ~plaintext
./stop_broker.sh

./start_broker.sh
bundle exec rspec -fd --tag integration --tag plaintext --tag ~tls
./stop_broker.sh
./teardown_broker.sh
