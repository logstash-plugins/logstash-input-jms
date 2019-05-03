require_relative '../spec_helper'
require 'logstash/inputs/jms'
require 'jms'
require 'json'
require 'securerandom'

shared_examples_for "a JMS input" do
  context 'when inputting messages' do
    it 'should receive a logstash event from the jms queue' do
      input.register
      queue  = []

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
              producer.send(session.message(message))
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
      expect(queue.size).to eql 1
      expect(queue.first.get('message')).to eql (message)
      expect(queue.first.get("jms_destination")).to eql(destination)
    end
  end
end

describe "input/jms", :integration => true do
  let (:message) { "hello World" }
  let (:queue_name) { SecureRandom.hex(8)}

  before :each do
    allow(input).to receive(:jms_config_from_yaml) do |yaml_file, section|
      settings = YAML.load_file(yaml_file)[section]
      settings[:require_jars] = [fixture_path("activemq-all.jar")]
      settings
    end
  end

  let (:yaml_section) { 'activemq' }
  let (:jms_config) {{'yaml_file' => fixture_path("jms.yml"),
                      'yaml_section' => yaml_section,
                      'destination' => queue_name,
                      'pub_sub' => pub_sub,
                      'interval' => 2}}
  let(:input) { LogStash::Plugin.lookup("input", "jms").new(jms_config) }

  after :each do
    input.close unless input.nil?
  end

  context 'with plaintext', :plaintext => true do

    context 'with pub_sub true' do
      let (:pub_sub) { true }
      it_behaves_like 'a JMS input'
    end

    context 'with pub_sub false' do
      let (:pub_sub) { false }
      it_behaves_like 'a JMS input'
    end

  end

  context 'with tls', :tls => true do
    let (:yaml_section) { 'activemq_tls' }
    let (:jms_config) { super.merge({"keystore" => fixture_path("keystore.jks"), "keystore_password" => "changeit",
                                     "truststore" => fixture_path("keystore.jks"), "truststore_password" => "changeit"})}

    context 'with pub_sub true' do
      let (:pub_sub) { true }
      it_behaves_like 'a JMS input'
    end

    context 'with pub_sub false' do
      let (:pub_sub) { false }
      it_behaves_like 'a JMS input'
    end
  end

end