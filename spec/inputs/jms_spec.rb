require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/jms"
require "jms"

def getYamlPath()
  return File.join(File.dirname(__FILE__),"jms.yml")
end

def populate(queue_name, content)
  require "logstash/event"

  jms_config = YAML.load_file(getYamlPath())["hornetq"]

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

class LogStash::Inputs::TestJms < LogStash::Inputs::Jms
  private
  def queue_event(msg, output_queue)
    super(msg, output_queue)
    # need to raise exception here to stop the infinite loop
    raise LogStash::ShutdownSignal
  end
end

describe "inputs/jms", :jms => true do
  let (:jms_config) {{'yaml_file' => getYamlPath(), 'yaml_section' => 'hornetq', 'destination' => 'ExampleQueue'}}

  it "should register" do
    input = LogStash::Plugin.lookup("input", "jms").new(jms_config)
    expect {input.register}.to_not raise_error
  end

  it 'should retrieve event from jms queue' do
    populate("ExampleQueue", "TestMessage")

    jmsInput = LogStash::Inputs::TestJms.new(jms_config)
    jmsInput.register

    logstash_queue = Queue.new
    jmsInput.run logstash_queue
    e = logstash_queue.pop
    insist { e['message'] } == 'TestMessage'
  end
end
