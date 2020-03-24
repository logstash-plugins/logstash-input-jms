#!/bin/bash
set -e
cp ./spec/inputs/fixtures/activemq_plaintext.xml activemq/conf/activemq.xml
activemq/bin/activemq start
