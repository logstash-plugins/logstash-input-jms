require_relative '../spec_helper'
require 'logstash/inputs/jms'
require 'jms'
require 'json'

shared_examples_for "a JMS input" do
  context 'when inputting messages' do

    it 'should receive a logstash event from the jms queue' do
      input.register
      queue  = []

      tt = Thread.new do
        sleep 5
        input.do_stop
      end
      input.run(queue)
      tt.join
      expect(queue.size).to eql 1
      expect(queue.first.get('message')).to eql (message)
      expect(queue.first.get("jms_destination")).to eql("queue://#{queue_name}")
    end
  end

end

describe "input/jms", :integration => true do
  let (:message) { "hello World" }
  let (:queue_name) { "ExampleQueue" }
  before :each do
    allow(input).to receive(:jms_config_from_yaml) do |yaml_file, section|
      settings = YAML.load_file(yaml_file)[section]
      settings[:require_jars] = [fixture_path("activemq-all.jar")]
      settings
    end
    properties_before_send = java.lang.System.getProperties
    begin
      input.load_ssl_properties
      # Check the message is correct on the queue.
      # Create config file to pass to JMS Connection
      config = input.jms_config_from_yaml(fixture_path('jms.yml'), yaml_section)
      raise "JMS Provider option:#{jms_provider} not found in jms.yml file" unless config

      # Consume all available messages on the queue
      JMS::Connection.session(config) do |session|
        session.producer(queue_name: queue_name) do |producer|
          producer.send(session.message(message))
        end
      end
    ensure
      java.lang.System.setProperties(properties_before_send)
    end
  end

  let (:yaml_section) { 'activemq' }
  let (:jms_config) {{'yaml_file' => fixture_path("jms.yml"), 'yaml_section' => yaml_section, 'destination' => queue_name}}
  let(:input) { LogStash::Plugin.lookup("input", "jms").new(jms_config) }

  after :each do
    input.close unless input.nil?
  end

  context 'with plaintext', :plaintext => true do
    it_behaves_like 'a JMS input'
  end

  context 'with tls', :tls => true do
    let (:yaml_section) { 'activemq_tls' }
    let (:jms_config) { super.merge({"keystore" => fixture_path("keystore.jks"), "keystore_password" => "changeit",
                                     "truststore" => fixture_path("keystore.jks"), "truststore_password" => "changeit"})}

    it_behaves_like 'a JMS input'
  end

end