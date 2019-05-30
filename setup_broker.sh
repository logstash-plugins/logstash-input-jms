#!/bin/bash
set -e

if [ -n "${ACTIVEMQ_VERSION+1}" ]; then
  echo "ACTIVEMQ_VERSION is $ACTIVEMQ_VERSION"
else
   ACTIVEMQ_VERSION=5.15.8
fi

curl -s -o activemq-all.jar http://central.maven.org/maven2/org/apache/activemq/activemq-all/$ACTIVEMQ_VERSION/activemq-all-$ACTIVEMQ_VERSION.jar
mv activemq-all.jar ./spec/inputs/fixtures/
curl -s -o activemq-bin.tar.gz  http://apache.mirrors.tds.net/activemq/$ACTIVEMQ_VERSION/apache-activemq-$ACTIVEMQ_VERSION-bin.tar.gz
tar xvf activemq-bin.tar.gz
mv apache-activemq-$ACTIVEMQ_VERSION activemq
