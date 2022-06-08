## 3.2.2
 - Fix: Remove usage of `java_kind_of?` to allow this plugin to be supported for versions of Logstash using jruby-9.3.x
 [#54](https://github.com/logstash-plugins/logstash-input-jms/pull/54)

## 3.2.1
 - Fix: improve compatibility with MessageConsumer implementations [#51](https://github.com/logstash-plugins/logstash-input-jms/pull/51),
   such as IBM MQ.
 - Test: Fix test failures due to ECS compatibility default changes in `8.x` of logstash [#53](https://github.com/logstash-plugins/logstash-input-jms/pull/53)

## 3.2.0
 - Feat: event_factory support + targets to aid ECS [#49](https://github.com/logstash-plugins/logstash-input-jms/pull/49)
 - Fix: when configured to add JMS headers to the event, headers whose value is not set no longer result in nil entries on the event
 - Fix: when adding the `jms_reply_to` header to an event, a string representation is set instead of an opaque object.

## 3.1.2
 - Docs: Added additional troubleshooting information [#38](https://github.com/logstash-plugins/logstash-input-jms/pull/38)

## 3.1.1
 - Added documentation for `factory_settings` configuration setting [#36](https://github.com/logstash-plugins/logstash-input-jms/pull/36)

## 3.1.0
 - Added many improvements to plugin [#35](https://github.com/logstash-plugins/logstash-input-jms/pull/35), including:  
   - Added support for TLS
   - Added support for durable subscriptions
   - Added support to skip processing of specified headers and properties
   - Added Integration tests
   - Added support for specifying system and connection factory settings in configuration
   - Improved error handling and reporting
   - Deprecated confusing runner settings, and simplified code.
   - Improved unit test coverage
   - Improved documentation with sample configurations and a basic troubleshooting guide

## 3.0.6
  - Fixed formatting issues in documentation [#32](https://github.com/logstash-plugins/logstash-input-jms/pull/32) and [#33](https://github.com/logstash-plugins/logstash-input-jms/pull/33]

## 3.0.5
  - Docs: Set the default_codec doc attribute.

## 3.0.4
  - Update gemspec summary

## 3.0.3
  - Fix some documentation issues

## 3.0.1
 - support nil body
 - fix dependency on semantic_logger (https://github.com/logstash-plugins/logstash-input-jms/issues/17)

## 3.0.0
 - Breaking: Updated plugin to use new Java Event APIs
 - relax logstash-core-plugin-api constrains
 - update .travis.yml
 - fix issue #6 - use missing calls from Plugin API - stop, close, stop?

## 2.0.4
 - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash

## 2.0.3
 - New dependency requirements for logstash-core for the 5.0 release

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

## 0.1.1
 - make the plugin, 1.5 friendly by using logstash-core
