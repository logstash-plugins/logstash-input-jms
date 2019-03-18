# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"

def fixture_path(file)
  File.join(File.dirname(__FILE__),"fixtures/#{file}")
end
