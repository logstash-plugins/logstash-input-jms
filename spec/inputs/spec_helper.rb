# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"

def fixture_path(file)
  File.join(File.dirname(__FILE__),"fixtures/#{file}")
end

def send_message(&block)
  input.register

  tt = Thread.new do
    sleep 1
    properties_before_send = java.lang.System.getProperties

    begin
      input.load_ssl_properties
      config = input.jms_config_from_yaml(fixture_path('jms.yml'), yaml_section)
      raise "JMS Provider option:#{jms_provider} not found in jms.yml file" unless config
      destination_key = pub_sub ? :topic_name : :queue_name
      JMS::Connection.session(config) do |session|
        session.producer(destination_key => queue_name) do |producer|
          msg = yield session unless block.nil?
          msg ||= session.message(message)
          producer.send(msg)
        end
        session.close
      end
      input.do_stop
    ensure
      java.lang.System.setProperties(properties_before_send)
    end
  end
  input.run(queue)

  destination = "#{pub_sub ? 'topic' : 'queue'}://#{queue_name}"
  tt.join(3)
end


def get_value(type, actual, name)
  actual.get(name) || actual.get("[@metadata][input][jms][#{type}][#{name}]")
end

def get_header_value(actual, name)
  get_value('headers', actual, name)
end

def get_property_value(actual, name)
  get_value('properties', actual, name)
end

RSpec::Matchers.define :have_header do |expected|
  match do |actual|
    get_header_value(actual, expected)
  end
end

RSpec::Matchers.define :have_property do |expected|
  match do |actual|
    get_property_value(actual, expected)
  end
end

RSpec::Matchers.define :have_header_value do |header, expected|
  match do |actual|
    expected == get_header_value(actual, header)
  end
end

RSpec::Matchers.define :have_property_value do |property, expected|
  match do |actual|
    expected == get_property_value(actual, property)
  end
end
