require_relative '../spec_helper'
require 'logstash/inputs/jms'
require 'logstash/plugin_mixins/ecs_compatibility_support/spec_helper'
require 'securerandom'

shared_examples_for "a JMS input" do
  context 'when inputting messages' do
    let (:destination) { "#{pub_sub ? 'topic' : 'queue'}://#{queue_name}"}
    let (:queue) { [] }

    context 'when the message is a text message' do
      let(:message) { "Hello There" }

      context 'when properties are skipped' do
        let (:config) { super().merge({'skip_properties' => ['this', 'that']})}

        it 'should skip the specified property and process other properties, headers and the message' do
          send_message do |session|
            msg = session.message(message)
            msg.set_string_property('this', 'this_prop')
            msg.set_string_property('that', 'that_prop')
            msg.set_string_property('the_other', 'the_other_prop')
            msg
          end
          expect(queue.first.get('message')).to eql(message)
          expect(queue.first).to have_header('jms_destination')
          expect(queue.first).to have_header('jms_timestamp')
          expect(queue.first).not_to have_property('this')
          expect(queue.first).not_to have_property('this')
          expect(queue.first).to have_property_value('the_other', 'the_other_prop')
        end
      end

      context 'when using message selectors' do
        let (:config) { super().merge({'selector' => selector }) }

        context 'with multiple selector query parameter' do
          let (:selector) { "this = 3 OR this = 4" }

          it 'process messages that conform to the message selector' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('that', 'that_prop')
              msg.set_int_property('this', 4)
              msg
            end
            expect(queue.first.get('message')).to eql(message)
            expect(queue.first).to have_property_value('this', 4)
            expect(queue.first).to have_property_value('that', 'that_prop')
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
            expect(queue.first.get('message')).to eql(message)
            expect(queue.first).to have_property_value('this', 3)
            expect(queue.first).to have_property_value('that', 'that_prop')
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
            expect(get_property_value(queue.first, 'this')).to be_within(0.001).of(3.1)
            expect(queue.first).to have_property_value('that', 'that_prop')
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
            expect(queue.first.get('message')).to eql(message)
            expect(queue.first).to have_property_value('this', 'this_prop')
            expect(queue.first).to have_property_value('that', 'that_prop')
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
        let (:config) { super().merge('skip_headers' => ['jms_destination', 'jms_reply_to']) }

        it 'should skip the specified header and process other headers, properties and the message' do
          send_message do |session|
            msg = session.message(message)
            msg.reply_to = session.create_destination(:topic_name => SecureRandom.hex(8))
            msg.set_string_property('this', 'this_prop')
            msg.set_string_property('that', 'that_prop')
            msg.set_string_property('the_other', 'the_other_prop')
            msg
          end
          expect(queue.first.get('message')).to eql(message)
          expect(queue.first).not_to have_header('jms_destination')
          expect(queue.first).to have_header('jms_timestamp')
          expect(queue.first).to have_property_value('this', 'this_prop')
          expect(queue.first).to have_property_value('that', 'that_prop')
          expect(queue.first).to have_property_value('the_other', 'the_other_prop')
        end
      end

      context 'when include_headers => false' do
        let (:config) { super().merge('include_headers' => 'false') }

        it 'should skip all headers' do
          send_message do |session|
            msg = session.message(message)
            msg.reply_to = session.create_destination(:topic_name => SecureRandom.hex(8))
            msg.set_string_property('some', 'property')
            msg
          end
          event = queue.first.to_hash_with_metadata
          expect( event.keys.find { |name| name.start_with?('jms_') } ).to be nil
        end
      end

      context 'when include_header => false (deprecated)' do
        let (:config) { super().merge('include_header' => 'false') }

        it 'should skip all headers' do
          send_message do |session|
            msg = session.message(message)
            msg.reply_to = session.create_destination(:topic_name => SecureRandom.hex(8))
            msg.set_string_property('some', 'property')
            msg
          end
          event = queue.first.to_hash_with_metadata
          expect( event.keys.find { |name| name.start_with?('jms_') } ).to be nil
        end
      end

      context 'when neither header nor property is skipped', :ecs_compatibility_support do
        ecs_compatibility_matrix(:disabled, :v1, :v8) do |ecs_select|

          let(:ecs_compatibility?) { ecs_select.active_mode != :disabled }

          let (:config) { super().merge('ecs_compatibility' => ecs_select.active_mode) }

          it 'should process properties, headers and the message' do
            send_message do |session|
              msg = session.message(message)
              msg.set_string_property('this', 'this_prop')
              msg.set_int_property('camelCase', 42)
              msg.set_boolean_property('JMSFlag', true)
              msg
            end

            event = queue.first

            expect(event.get('message')).to eql(message)

            # headers
            if ecs_compatibility?
              expect(event.include?('jms_timestamp')).to be false
              expect(event.include?('jms_destination')).to be false
              expect(event.get('[@metadata][input][jms][headers][jms_timestamp]')).to be_a Integer
              expect(event.get('[@metadata][input][jms][headers][jms_destination]')).to_not be nil
              expect(event.include?("[@metadata][input][jms][headers][jms_delivery_mode_sym]")).to be false
              expect(event.include?("[@metadata][input][jms][headers][jms_delivery_mode]")).to be true
            else
              expect(event.get('jms_timestamp')).to be_a Integer
              expect(event.get('jms_destination')).to_not be nil
              expect(event.include?("jms_delivery_mode_sym")).to be true
            end

            # properties
            if ecs_compatibility?
              expect(event.include?('this')).to be false
              expect(event.get('[@metadata][input][jms][properties][this]')).to eq 'this_prop'
              expect(event.get('[@metadata][input][jms][properties][camelCase]')).to eq 42
              expect(event.get('[@metadata][input][jms][properties][JMSFlag]')).to be true
            else
              expect(event.get('this')).to eq 'this_prop'
              expect(event.get('camelCase')).to eq 42
              expect(event.get('JMSFlag')).to be true
            end
          end

        end
      end

      context 'when using a multi-event codec' do
        let(:config) { super().merge('codec' => 'line') }
        let(:message) { 'one' + "\n" + 'two' + "\n" + 'three' }
        it 'emits multiple events' do
          send_message do |session|
            session.message(message)
          end
          expect(queue.size).to eql 3
          expect(queue.map { |e| e.get('message') }).to contain_exactly("one", "two", "three")
          expect(queue).to all(have_header_value("jms_destination", destination))
        end
      end
    end

    context 'when the message is map message', :ecs_compatibility_support do

      ecs_compatibility_matrix(:disabled, :v1, :v8) do |ecs_select|

        let(:ecs_compatibility?) { ecs_select.active_mode != :disabled }

        let (:config) { super().merge('ecs_compatibility' => ecs_select.active_mode) }

        let(:message) { {:one => 1} }

        before do
          if ecs_compatibility?
            expect(subject.logger).to receive(:info).once.with /ECS compatibility is enabled but `target` option was not specified/i
          end
        end

        it 'should read the message' do
          send_message

          expect(queue.size).to eql 1
          event = queue.first
          expect(event.get('one')).to eql 1

          if ecs_compatibility?
            expect(event.get('[@metadata][input][jms][headers][jms_destination]')).to eql(destination)
            expect(event.get('[@metadata][input][jms][headers][jms_delivery_mode]')).to eql 'persistent'
            expect(event.include?('[@metadata][input][jms][headers][jms_delivery_mode_sym]')).to be false
          else
            expect(event.get("jms_destination")).to eql(destination)
            expect(event.get("jms_delivery_mode_sym")).to eql :persistent
          end

          send_message # should not log the ECS warning again
        end

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
        expect(queue.first.get('message')).to eql 'hello world'
        expect(queue.first).to have_header_value("jms_destination", destination)
      end
    end
  end
end

describe LogStash::Inputs::Jms, :integration => true do
  let (:message) { "hello World" }
  let (:queue_name) { SecureRandom.hex(8)}

  let (:yaml_section) { 'activemq' }
  let (:config) {{'yaml_file' => fixture_path("jms.yml"),
                      'yaml_section' => yaml_section,
                      'destination' => queue_name,
                      'pub_sub' => pub_sub,
                      'interval' => 2}}

  subject(:input) { described_class.new(config) }

  before :each do
    allow(input).to receive(:jms_config_from_yaml) do |yaml_file, section|
      settings = YAML.load_file(yaml_file)[section]
      settings[:require_jars] = [fixture_path("activemq-all.jar")]
      settings
    end
  end

  after :each do
    input.close unless input.nil?
  end

  context 'with plaintext', :plaintext => true do
    context 'with pub_sub true' do
      let (:pub_sub) { true }
      it_behaves_like 'a JMS input'
    end

    context 'with pub_sub true and durable subscriber' do
      let (:config) { super().merge({'durable_subscriber' => true,
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
    let (:config) { super().merge({"keystore" => fixture_path("keystore.jks"), "keystore_password" => "changeit",
                                   "truststore" => fixture_path("keystore.jks"), "truststore_password" => "changeit"})}

    context 'with pub_sub true' do
      let (:pub_sub) { true }
      it_behaves_like 'a JMS input'
    end

    context 'with pub_sub true and durable subscriber' do
      let (:config) { super().merge({'durable_subscriber' => true,
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