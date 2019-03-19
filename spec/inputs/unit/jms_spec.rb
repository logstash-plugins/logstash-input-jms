require_relative '../spec_helper'
require 'logstash/inputs/jms'
require 'jms'
require 'json'

describe "inputs/jms" do

  describe 'initialization' do
    let (:yaml_section) { 'activemq' }
    let (:jms_config) {{'yaml_file' => fixture_path(file), 'yaml_section' => yaml_section, 'destination' => 'ExampleQueue'}}

    context 'via yaml file' do
      context 'simple yaml configuration' do
        let (:file) { "jms.yml" }

        it 'should populate jms config from the yaml file' do
          jms = LogStash::Inputs::Jms.new(jms_config)
          expect(jms.jms_config).to include({:broker_url => "tcp://localhost:61616",
                                             :factory=>"org.apache.activemq.ActiveMQConnectionFactory",
                                             :require_jars=>["activemq-all.jar"]})
        end
      end

      context 'jndi yaml configuration' do
        let (:file) { "jndijms.yml" }
        let (:yaml_section) { 'solace' }
        it 'should populate jms config from the yaml file' do
          jms = LogStash::Inputs::Jms.new(jms_config)
          expect(jms.jms_config).to include({:jndi_context=>{
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

    context 'simple configuration' do
      let (:jms_config) {{
          'destination' => 'ExampleQueue',
          'username' => 'user',
          'password' => 'the_password',
          'broker_url' => 'tcp://localhost:61616',
          'pub_sub' => true,
          'factory' => 'org.apache.activemq.ActiveMQConnectionFactory',
          'require_jars' => ['activemq-all-5.15.8.jar']
      }}
      it 'should populate jms config from the configuration' do
        jms = LogStash::Inputs::Jms.new(jms_config)
        expect(jms.jms_config).to include({:broker_url => "tcp://localhost:61616",
                                           :factory=>"org.apache.activemq.ActiveMQConnectionFactory",
                                           :require_jars=>["activemq-all-5.15.8.jar"]})
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
        jms = LogStash::Inputs::Jms.new(jms_config)
        expect(jms.jms_config).to include({:jndi_context=>{
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