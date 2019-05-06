require_relative '../spec_helper'
require 'logstash/inputs/jms'
require 'jms'
require 'json'

describe "inputs/jms" do

  describe 'initialization' do
    let (:queue_name) {SecureRandom.hex(8)}
    let (:jms_config) {{'destination' => queue_name}}

    subject(:plugin) { LogStash::Inputs::Jms.new(jms_config) }

    context 'configuration check' do

      context 'with pub_sub set to true' do
        let(:jms_config) { super.merge({'pub_sub' => true})}

        context 'if threads is > 1' do
          let(:jms_config) { super.merge({'threads' => 2})}
          it 'should raise a configuration error' do
            expect { plugin.register }.to raise_error(LogStash::ConfigurationError)
          end
        end
      end

      context 'with durable_subscriber set' do
        let(:jms_config) { super.merge({ 'pub_sub' => true,
                                         'durable_subscriber' => true,
                                         'durable_subscriber_name' => SecureRandom.hex(8),
                                         'durable_subscriber_client_id' => SecureRandom.hex(8)})}

        context 'if durable_subscriber_client_id is not set' do
          let(:jms_config) { super.tap { |h| h.delete('durable_subscriber_client_id') } }

          it 'should set client_id to Logstash' do
            plugin.register
            expect(plugin.durable_subscriber_client_id).to eq('Logstash')
          end
        end

        context 'if durable_subscriber_name is not set' do
          let(:jms_config) { super.tap { |h| h.delete('durable_subscriber_name') } }

          it 'should set name to the topic name' do
            plugin.register
            expect(plugin.durable_subscriber_name).to eq(queue_name)
          end
        end


        context 'if pub_sub is set to false' do
          let(:jms_config) { super.merge({'pub_sub' => false})}
          it 'should raise a configuration error' do
            expect { plugin.register }.to raise_error(LogStash::ConfigurationError)
          end
        end
      end
    end


    context 'via yaml file' do
      let (:yaml_section) { 'activemq' }
      let (:jms_config) {{'yaml_file' => fixture_path(file), 'yaml_section' => yaml_section, 'destination' => SecureRandom.hex(8)}}

      context 'simple yaml configuration' do
        let (:file) { "jms.yml" }
        let (:password) { 'the_password' }

        it 'should populate jms config from the yaml file' do
          expect(plugin.jms_config).to include({:broker_url => "tcp://localhost:61616",
                                             :password => password,
                                             :factory=>"org.apache.activemq.ActiveMQConnectionFactory",
                                             :require_jars=>["activemq-all.jar"]})
        end
        it 'should not log the password in plaintext' do
          expect(plugin.logger).to receive(:debug) do |_, params|
            expect(params[:context]).to include(:password)
            expect(params[:context][:password]).not_to eq(password)
          end

          plugin.register
        end

      end

      context 'jndi yaml configuration' do
        let (:file) { "jndijms.yml" }
        let (:yaml_section) { 'solace' }

        it 'should populate jms config from the yaml file' do
          expect(plugin.jms_config).to include({:jndi_context=>{
              "java.naming.factory.initial"=>"com.solacesystems.jndi.SolJNDIInitialContextFactory",
              "java.naming.security.principal"=>"username",
              "java.naming.provider.url"=>"tcp://localhost:20608",
              "java.naming.security.credentials"=>"password"},
                                             :jndi_name => "/jms/cf/default",
                                             :require_jars => ["commons-lang-2.6.jar",
                                                               "sol-jms-10.5.0.jar",
                                                               "geronimo-jms_1.1_spec-1.1.1.jar",
                                                               "commons-lang-2.6.jar"]})
        end
        it 'should not log the password in plaintext' do
          expect(plugin.logger).to receive(:debug) do |_, params|
            expect(params[:context]).not_to include(:password)
          end
          plugin.register
        end
      end
    end

    context 'simple configuration' do
      let (:password) { 'the_password' }
      let (:jms_config) {{
          'destination' => 'ExampleQueue',
          'username' => 'user',
          'password' => password,
          'broker_url' => 'tcp://localhost:61616',
          'pub_sub' => true,
          'factory' => 'org.apache.activemq.ActiveMQConnectionFactory',
          'require_jars' => ['activemq-all-5.15.8.jar']
      }}
      it 'should populate jms config from the configuration' do
        expect(plugin.jms_config).to include({:broker_url => "tcp://localhost:61616",
                                           :factory=>"org.apache.activemq.ActiveMQConnectionFactory",
                                           :require_jars=>["activemq-all-5.15.8.jar"]})
      end
      it 'should not log the password in plaintext' do
        expect(plugin.logger).to receive(:debug) do |_, params|
          expect(params[:context]).to include(:password)
          expect(params[:context][:password]).not_to eq(password)
        end

        plugin.register
      end
    end

    context 'simple configuration with jndi' do
      let (:jms_config) {{
          'destination' => 'ExampleQueue',
          'jndi_name' => "/jms/cf/default",
          "jndi_context" => {
              "java.naming.factory.initial"=>"com.solacesystems.jndi.SolJNDIInitialContextFactory",
              "java.naming.security.principal"=>"username",
              "java.naming.provider.url"=>"tcp://localhost:20608",
              "java.naming.security.credentials"=>"password"},
          'pub_sub' => true,
          "require_jars" => ["commons-lang-2.6.jar",
                             "sol-jms-10.5.0.jar",
                             "geronimo-jms_1.1_spec-1.1.1.jar",
                             "commons-lang-2.6.jar"]}}


      it 'should populate jms config from the configuration' do
        expect(plugin.jms_config).to include({:jndi_context=>{
            "java.naming.factory.initial"=>"com.solacesystems.jndi.SolJNDIInitialContextFactory",
            "java.naming.security.principal"=>"username",
            "java.naming.provider.url"=>"tcp://localhost:20608",
            "java.naming.security.credentials"=>"password"},
                                           :jndi_name => "/jms/cf/default",
                                           :require_jars => ["commons-lang-2.6.jar",
                                                             "sol-jms-10.5.0.jar",
                                                             "geronimo-jms_1.1_spec-1.1.1.jar",
                                                             "commons-lang-2.6.jar"]})
      end
    end
  end
end