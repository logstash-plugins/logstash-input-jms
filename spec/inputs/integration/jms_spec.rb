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

      context 'when properties are skipped' do
        let (:jms_config) { super.merge({'skip_properties' => ['this', 'that']})}

        it 'should skip the specified property and process other properties, headers and the message' do
          send_message do |session|
            msg = session.message(message)
            msg.set_string_property('this', 'this_prop')
            msg.set_string_property('that', 'that_prop')
            msg.set_string_property('the_other', 'the_other_prop')
            msg
          end
          expect(queue.first.get('message')).to eql (message)
          expect(queue.first.get('jms_destination')).to_not be_nil
          expect(queue.first.get('jms_timestamp')).to_not be_nil
          expect(queue.first.get('this')).to be_nil
          expect(queue.first.get('that')).to be_nil
          expect(queue.first.get('the_other')).to eql('the_other_prop')
        end
      end

      context 'when using message selectors' do
        let (:jms_config) { super.merge({'selector' => selector }) }

        context 'with multiple selector query parameter' do
          let (:selector) { "this = 3 OR this = 4" }

          it 'process messages that conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('that', 'that_prop')
              msg.set_int_property('this', 4)
              msg
            end
            expect(queue.first.get('message')).to eql (message)
            expect(queue.first.get('this')).to eql(4)
            expect(queue.first.get('that')).to eql('that_prop')
          end

          it 'does not process messages that do not conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('this', 'that_prop')
              msg.set_string_property('that', 'this_prop')
              msg
            end
            expect(queue.size).to be 0
          end
        end

        context 'with an integer property' do
          let (:selector) { "this < 4" }

          it 'process messages that conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('that', 'that_prop')
              msg.set_int_property('this', 3)
              msg
            end
            expect(queue.first.get('message')).to eql (message)
            expect(queue.first.get('this')).to eql(3)
            expect(queue.first.get('that')).to eql('that_prop')
          end

          it 'does not process messages that do not conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('this', 'that_prop')
              msg.set_string_property('that', 'this_prop')
              msg
            end
            expect(queue.size).to be 0
          end
        end

        context 'with a float property' do
          let (:selector) { "this < 3.3" }

          it 'process messages that conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('that', 'that_prop')
              msg.set_float_property('this', 3.1)
              msg
            end
            expect(queue.first.get('message')).to eql(message)
            expect(queue.first.get('this')).to be_within(0.001).of(3.1)
            expect(queue.first.get('that')).to eql('that_prop')
          end

          it 'does not process messages that do not conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('this', 'that_prop')
              msg.set_string_property('that', 'this_prop')
              msg
            end
            expect(queue.size).to be 0
          end
        end


        context 'with a string property' do
          let (:selector) { "this = 'this_prop'" }

          it 'process messages that conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('this', 'this_prop')
              msg.set_string_property('that', 'that_prop')
              msg
            end
            expect(queue.first.get('message')).to eql (message)
            expect(queue.first.get('this')).to eql('this_prop')
            expect(queue.first.get('that')).to eql('that_prop')
          end

          it 'does not process messages that do not conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('this', 'that_prop')
              msg.set_string_property('that', 'this_prop')
              msg
            end
            expect(queue.size).to be 0
          end

        end
      end
      context 'when headers are skipped' do
        let (:jms_config) { super.merge({'skip_headers' => ['jms_destination', 'jms_reply_to']})}
        it 'should skip the specified header and process other headers, properties and the message' do
          send_message do |session|
            msg = session.message(message)
            msg.reply_to = session.create_destination(:topic_name => SecureRandom.hex(8))
            msg.set_string_property('this', 'this_prop')
            msg.set_string_property('that', 'that_prop')
            msg.set_string_property('the_other', 'the_other_prop')
            msg
          end
          expect(queue.first.get('message')).to eql (message)
          expect(queue.first.get('jms_destination')).to be_nil
          expect(queue.first.get('jms_timestamp')).to_not be_nil
          expect(queue.first.get('this')).to eq('this_prop')
          expect(queue.first.get('that')).to eq('that_prop')
          expect(queue.first.get('the_other')).to eq('the_other_prop')
        end
      end

      context 'when neither header nor property is skipped ' do
        it 'should process properties, headers and the message' do
          send_message do |session|
            msg = session.message(message)
            msg.set_string_property('this', 'this_prop')
            msg.set_string_property('that', 'that_prop')
            msg.set_string_property('the_other', 'the_other_prop')
            msg
          end
          expect(queue.first.get('message')).to eql (message)
          expect(queue.first.get('jms_timestamp')).to_not be_nil
          expect(queue.first.get('jms_destination')).to_not be_nil
          expect(queue.first.get('this')).to eq('this_prop')
          expect(queue.first.get('that')).to eq('that_prop')
          expect(queue.first.get('the_other')).to eq('the_other_prop')
        end
      end

      context 'when delivery mode is set' do
        let(:jms_config) { super.merge {} }
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
                           'durable_subscriber_name' => SecureRandom.hex(8) } ) }

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
                           'durable_subscriber_name' => SecureRandom.hex(8) } ) }

      let (:pub_sub) { true }

      it_behaves_like 'a JMS input'
    end

    context 'with pub_sub false' do
      let (:pub_sub) { false }
      it_behaves_like 'a JMS input'
    end
  end
end