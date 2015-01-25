require "logstash/devutils/rspec/spec_helper"
require "jms"

def populate(queue_name, content)
  require "logstash/event"

  jms_config = {
    :jndi_name => "/ConnectionFactory",
    :jndi_context => {
      'java.naming.factory.initial'=> 'org.jnp.interfaces.NamingContextFactory',
      'java.naming.provider.url'=> 'jnp://localhost:1099',
      'java.naming.factory.url.pkgs'=> 'org.jboss.naming:org.jnp.interfaces',
      'java.naming.security.principal'=> 'guest',
      'java.naming.security.credentials'=> 'guest'},
    :require_jars => [
      "/Applications/hornetq-2.4.0.Final/lib/hornetq-commons.jar",
      "/Applications/hornetq-2.4.0.Final/lib/hornetq-core-client.jar",
      "/Applications/hornetq-2.4.0.Final/lib/hornetq-jms-client.jar",
      "/Applications/hornetq-2.4.0.Final/lib/jboss-jms-api.jar",
      "/Applications/hornetq-2.4.0.Final/lib/jnp-client.jar",
      "/Applications/hornetq-2.4.0.Final/lib/netty.jar"]
  }

  JMS::Connection.session(jms_config) do |session|
    session.producer(:queue_name => queue_name) do |producer|
      producer.send(session.message(content))
    end
  end
end

def process(pipeline, queue, content)
  sequence = 0
  Thread.new { pipeline.run }
  event = queue.pop
  pipeline.shutdown
end # process

describe "inputs/jms", :jms => true do


  describe "read events from a queue" do
    queue_name = "ExampleQueue"
    content = "number " + (1000 + rand(50)).to_s
    config <<-CONFIG
    input {
      jms {
        jndi_name => "/ConnectionFactory"
        jndi_context => {
          "java.naming.factory.initial"=> "org.jnp.interfaces.NamingContextFactory"
          "java.naming.provider.url"=> "jnp://localhost:1099"
          "java.naming.factory.url.pkgs"=> "org.jboss.naming:org.jnp.interfaces"
          "java.naming.security.principal"=> "guest"
          "java.naming.security.credentials"=> "guest"
        }
        require_jars => [
          "/Applications/hornetq-2.4.0.Final/lib/hornetq-commons.jar",
          "/Applications/hornetq-2.4.0.Final/lib/hornetq-core-client.jar",
          "/Applications/hornetq-2.4.0.Final/lib/hornetq-jms-client.jar",
          "/Applications/hornetq-2.4.0.Final/lib/jboss-jms-api.jar",
          "/Applications/hornetq-2.4.0.Final/lib/jnp-client.jar",
          "/Applications/hornetq-2.4.0.Final/lib/netty.jar"
        ]
        destination => "#{queue_name}"
      }
    }
    CONFIG

    before(:each) { populate(queue_name, content) }

    input { |pipeline, queue| process(pipeline, queue, content) }
  end

  # describe "read events from a list with batch_count=5" do
  #   key = 10.times.collect { rand(10).to_s }.join("")
  #   event_count = 1000 + rand(50)
  #   config <<-CONFIG
  #   input {
  #     redis {
  #       type => "blah"
  #       key => "#{key}"
  #       data_type => "list"
  #       batch_count => #{rand(20)+1}
  #     }
  #   }
  #   CONFIG
  #
  #   before(:each) { populate(key, event_count) }
  #   input { |pipeline, queue| process(pipeline, queue, event_count) }
  # end
end
