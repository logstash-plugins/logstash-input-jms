# encoding: utf-8
require "logstash/inputs/base"
require "logstash/inputs/threadable"
require "logstash/namespace"

# Read events from a Jms Broker. Supports both Jms Queues and Topics.
#
# For more information about Jms, see <http://docs.oracle.com/javaee/6/tutorial/doc/bncdq.html>
# For more information about the Ruby Gem used, see <http://github.com/reidmorrison/jruby-jms>
# Here is a config example to pull from a queue:
#  jms {
#     include_header => false
#     include_properties => false
#     include_body => true
#     use_jms_timestamp => false
#     interval => 10
#     destination => "myqueue"
#     pub-sub => false
#     yaml_file => "~/jms.yml"
#     yaml_section => "mybroker"
#   }
#
#
class LogStash::Inputs::Jms < LogStash::Inputs::Threadable
  config_name "jms"

  # A JMS message has three parts :
  #  Message Headers (required)
  #  Message Properties (optional)
  #  Message Bodies (optional)
  # You can tell the input plugin which parts should be included in the event produced by Logstash
  #
  # Include JMS Message Header Field values in the event
  config :include_header, :validate => :boolean, :default => true
  # Include JMS Message Properties Field values in the event
  config :include_properties, :validate => :boolean, :default => true
  # Include JMS Message Body in the event
  # Supports TextMessage, MapMessage and ByteMessage
  # If the JMS Message is a TextMessage or ByteMessage, then the value will be in the "message" field of the event
  # If the JMS Message is a MapMessage, then all the key/value pairs will be added in the Hashmap of the event
  # StreamMessage and ObjectMessage are not supported
  config :include_body, :validate => :boolean, :default => true
  
  # Convert the JMSTimestamp header field to the @timestamp value of the event
  config :use_jms_timestamp, :validate => :boolean, :default => false

  # Choose an implementation of the run block. Value can be either consumer, async or thread
  config :runner, :validate => [ "consumer", "async", "thread" ], :default => "consumer"

  # Set the selector to use to get messages off the queue or topic
  config :selector, :validate => :string

  # Initial connection timeout in seconds.
  config :timeout, :validate => :number, :default => 60

  # Polling interval in seconds.
  # This is the time sleeping between asks to a consumed Queue.
  # This parameter has non influence in the case of a subcribed Topic.
  config :interval, :validate => :number, :default => 10

  # If pub-sub (topic) style should be used.
  config :pub_sub, :validate => :boolean, :default => false

  # Name of the destination queue or topic to use.
  config :destination, :validate => :string, :required => true

  # Yaml config file
  config :yaml_file, :validate => :string
  # Yaml config file section name
  # For some known examples, see: [Example jms.yml](https://github.com/reidmorrison/jruby-jms/blob/master/examples/jms.yml)
  config :yaml_section, :validate => :string

  # If you do not use an yaml configuration use either the factory or jndi_name.

  # An optional array of Jar file names to load for the specified
  # JMS provider. By using this option it is not necessary
  # to put all the JMS Provider specific jar files into the
  # java CLASSPATH prior to starting Logstash.
  config :require_jars, :validate => :array

  # Name of JMS Provider Factory class
  config :factory, :validate => :string
  # Username to connect to JMS provider with
  config :username, :validate => :string
  # Password to use when connecting to the JMS provider
  config :password, :validate => :string
  # Url to use when connecting to the JMS provider
  config :broker_url, :validate => :string

  # Name of JNDI entry at which the Factory can be found
  config :jndi_name, :validate => :string
  # Mandatory if jndi lookup is being used,
  # contains details on how to connect to JNDI server
  config :jndi_context, :validate => :hash

  # :yaml_file, :factory and :jndi_name are mutually exclusive, both cannot be supplied at the
  # same time. The priority order is :yaml_file, then :jndi_name, then :factory
  #
  # JMS Provider specific properties can be set if the JMS Factory itself
  # has setters for those properties.
  #
  # For some known examples, see: [Example jms.yml](https://github.com/reidmorrison/jruby-jms/blob/master/examples/jms.yml)

  public
  def register
    require "jms"
    @connection = nil

    if @yaml_file
      @jms_config = YAML.load_file(@yaml_file)[@yaml_section]

    elsif @jndi_name
      @jms_config = {
        :require_jars => @require_jars,
        :jndi_name => @jndi_name,
        :jndi_context => @jndi_context}

    elsif @factory
      @jms_config = {
        :require_jars => @require_jars,
        :factory => @factory,
        :username => @username,
        :password => @password,
        :broker_url => @broker_url,
        :url => @broker_url # "broker_url" is named "url" with Oracle AQ
      }
    end

    @logger.debug("JMS Config being used", :context => @jms_config)

  end # def register


  private
  def queue_event(msg, output_queue)
    begin
      if @include_body
        if msg.java_kind_of?(JMS::MapMessage)
          event = LogStash::Event.new
          msg.data.each do |field, value|
            event.set(field.to_s, value) # TODO(claveau): needs codec.decode or converter.convert ?
          end
        elsif msg.java_kind_of?(JMS::TextMessage) || msg.java_kind_of?(JMS::BytesMessage)
          if !msg.to_s.nil?
            @codec.decode(msg.to_s) do |event_message|
              event = event_message
            end
          end
        else
          @logger.error( "Unknown data type #{msg.data.class.to_s} in Message" )
        end
      end

      event ||= LogStash::Event.new

      # Here, we can use the JMS Enqueue timestamp as the @timestamp
      if @use_jms_timestamp && msg.jms_timestamp
        event.set("@timestamp", LogStash::Timestamp.at(msg.jms_timestamp / 1000, (msg.jms_timestamp % 1000) * 1000))
      end

      if @include_header
        msg.attributes.each do |field, value|
          event.set(field.to_s, value)
        end
      end

      if @include_properties
        msg.properties.each do |field, value|
          event.set(field.to_s, value)
        end
      end

      decorate(event)
      output_queue << event

    rescue => e # parse or event creation error
      @logger.error("Failed to create event", :message => msg, :exception => e,
                    :backtrace => e.backtrace);
    end
  end

  # Consume all available messages on the queue
  # sleeps some time, then consume again
  private
  def run_consumer(output_queue)
    JMS::Connection.session(@jms_config) do |session|
      destination_key = @pub_sub ? :topic_name : :queue_name
      while !stop?
        session.consume(destination_key => @destination, :timeout=>@timeout, :selector => @selector) do |message|
          queue_event message, output_queue
          break if stop?
        end
        sleep @interval
      end
    end
  rescue => e
    @logger.warn("JMS Consumer died", :exception => e, :backtrace => e.backtrace)
    sleep(10)
    retry unless stop?
  end # def run_consumer

  # Consume all available messages on the queue through a listener
  private
  def run_thread(output_queue)
    connection = JMS::Connection.new(@jms_config)
    connection.on_exception do |jms_exception|
      @logger.warn("JMS Exception has occurred: #{jms_exception}")
    end

    destination_key = @pub_sub ? :topic_name : :queue_name
    connection.on_message(destination_key => @destination, :selector => @selector) do |message|
      queue_event message, output_queue
    end
    connection.start
    while !stop?
      @logger.debug("JMS Thread sleeping ...")
      sleep @interval
    end
  rescue => e
    @logger.warn("JMS Consumer died", :exception => e, :backtrace => e.backtrace)
    sleep(10)
    retry unless stop?
  end # def run_thread

  # Consume all available messages on the queue through a listener
  private
  def run_async(output_queue)
    JMS::Connection.start(@jms_config) do |connection|
      # Define exception listener
      # The problem here is that we do not handle any exception
      connection.on_exception do |jms_exception|
        @logger.warn("JMS Exception has occurred: #{jms_exception}")
        raise jms_exception
      end
      # Define Asynchronous code block to be called every time a message is received
      destination_key = @pub_sub ? :topic_name : :queue_name
      connection.on_message(destination_key => @destination, :selector => @selector) do |message|
        queue_event message, output_queue
      end
      # Since the on_message handler above is in a separate thread the thread needs
      # to do some other work. It will just sleep for 10 seconds.
      while !stop?
        @logger.debug("JMS Thread sleeping ...")
        sleep @interval
      end
    end
  rescue => e
    @logger.warn("JMS Consumer died", :exception => e, :backtrace => e.backtrace)
    sleep(10)
    retry unless stop?
  end # def run_async

  public
  def run(output_queue)
    case @runner
    when "consumer" then
      run_consumer(output_queue)
    when "async" then
      run_async(output_queue)
    when "thread" then
      run_thread(output_queue)
    end
  end # def run

  public
  def close
    @logger.info("Closing JMS connection")
    @connection.close rescue nil
  end # def close

  public
  def stop
    @logger.info("Stopping JMS consumer")
    @connection.stop rescue nil
  end # def stop
end # class LogStash::Inputs::Jms
