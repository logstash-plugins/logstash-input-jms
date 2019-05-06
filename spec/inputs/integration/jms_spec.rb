require_relative '../spec_helper'
require 'logstash/inputs/jms'
require 'jms'
require 'json'
require 'securerandom'



shared_examples_for "a JMS input" do
  context 'when inputting messages' do
    let (:destination) { "#{pub_sub ? 'topic' : 'queue'}://#{queue_name}"}
    let (:queue) { [] }

    context 'when the message is a text message' do
      let(:message) { "Hello There" }

      it 'process the property and the message' do
        send_message do |session|
          msg = session.message(message)
          msg.set_string_property('this', 'that')
          msg
        end
        expect(queue.first.get('message')).to eql (message)
        expect(queue.first.get('this')).to eql('that')
      end

      context 'when the property is skipped' do
        let (:jms_config) { super.merge({'skip_properties' => ['this']})}

        it 'should skip the property and process the message' do
          send_message do |session|
            msg = session.message(message)
            msg.set_string_property('this', 'that')
            msg
          end
          expect(queue.first.get('message')).to eql (message)
          expect(queue.first.get('this')).to be_nil
        end
      end

      context 'when the header is skipped' do
        let (:jms_config) { super.merge({'skip_headers' => ['jms_reply_to']})}
        it 'should skip the property and read the message' do
          send_message do |session|
            msg = session.message(message)
            msg.reply_to = session.create_destination(:topic_name => SecureRandom.hex(8))
            msg
          end
          expect(queue.first.get('message')).to eql (message)
          expect(queue.first.get('jms_reply_to')).to be_nil
        end
      end

      context 'when the header is skipped' do
        it 'should skip the property and read the message' do
          send_message do |session|
            msg = session.message(message)
            msg.reply_to = session.create_destination(:topic_name => SecureRandom.hex(8))
            msg
          end
          expect(queue.first.get('message')).to eql (message)
          expect(queue.first.get('jms_reply_to')).to_not be_nil
        end
      end

      it 'should receive a logstash event from the jms queue' do
        send_message
        expect(queue.size).to eql 1
        expect(queue.first.get('message')).to eql (message)
        expect(queue.first.get("jms_destination")).to eql(destination)
      end
    end

    context 'when the message is map message' do
      let(:message) { {:one => 1} }
      it 'should read the message' do
        send_message
        expect(queue.size).to eql 1
        expect(queue.first.get('one')).to eql (1)
        expect(queue.first.get("jms_destination")).to eql(destination)
      end
    end

    context 'when the message is a bytes message' do
      let(:message) { 'hello world'.to_java_bytes }

      it 'should read the message' do
        send_message do |session|
          jms_message = session.createBytesMessage
          jms_message.write_bytes(message)
          jms_message
        end
        expect(queue.size).to eql 1
        expect(queue.first.get('message')).to eql ('hello world')
        expect(queue.first.get("jms_destination")).to eql(destination)
      end
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

    context 'with pub_sub true and durable subscriber' do
      let (:jms_config) { super.merge({'durable_subscriber' => true,
                           'durable_subscriber_client_id' => SecureRandom.hex(8),
                           'durable_subscriber_name' => SecureRandom.hex(8) } }

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

    context 'with pub_sub true and durable subscriber' do
      let (:jms_config) { super.merge({'durable_subscriber' => true,
                           'durable_subscriber_client_id' => SecureRandom.hex(8),
                           'durable_subscriber_name' => SecureRandom.hex(8) } }

      let (:pub_sub) { true }

      it_behaves_like 'a JMS input'
    end

    context 'with pub_sub false' do
      let (:pub_sub) { false }
      it_behaves_like 'a JMS input'
    end
  end

end