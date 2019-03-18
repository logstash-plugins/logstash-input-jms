require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/jms"
require "jms"

describe LogStash::Inputs::Jms do
  let(:queue) { Queue.new }
  let(:jms_config) {{:require_jars => ["some.jar"],  :jndi_name => "", :jndi_context => {}}}
  let(:config) do
    config = { "destination" => "ExampleQueue" }
    jms_config.each {|k, v| config[k.to_s] = v }
    config
  end
  subject { LogStash::Inputs::Jms.new(config.dup) }

  context "using default runner (consumer)" do
    before :each do
      subject.register
    end

    it "should call the consumer runner" do
      expect(subject).to receive(:run_consumer).with(queue)
      subject.run(queue)
    end

    it "should create a JMS session based on JMS config" do
      expect(JMS::Connection).to receive(:session).with(jms_config)
      subject.run(queue)
    end
  end
end
