# encoding: utf-8
require "logstash/inputs/base"
require "logstash/inputs/threadable"
require 'java'
require "logstash/namespace"

require 'logstash/plugin_mixins/ecs_compatibility_support'
require 'logstash/plugin_mixins/ecs_compatibility_support/target_check'
require 'logstash/plugin_mixins/event_support/event_factory_adapter'
require 'logstash/plugin_mixins/validator_support/field_reference_validation_adapter'

# Read events from a Jms Broker. Supports both Jms Queues and Topics.
#
# For more information about Jms, see <http://docs.oracle.com/javaee/6/tutorial/doc/bncdq.html>
# For more information about the Ruby Gem used, see <http://github.com/reidmorrison/jruby-jms>
# Here is a config example to pull from a queue:
#  jms {
#     include_headers => false
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

  include LogStash::PluginMixins::ECSCompatibilitySupport(:disabled, :v1, :v8 => :v1)
  include LogStash::PluginMixins::EventSupport::EventFactoryAdapter

  extend LogStash::PluginMixins::ValidatorSupport::FieldReferenceValidationAdapter

  config_name "jms"

  # A JMS message has three parts :
  #  Message Headers (required)
  #  Message Properties (optional)
  #  Message Bodies (optional)
  # You can tell the input plugin which parts should be included in the event produced by Logstash
  #
  # Include JMS Message Header Field values in the event
  config :include_header, :validate => :boolean, :deprecated => "Set 'include_headers => ...' instead"
  config :include_headers, :validate => :boolean, :default => true
  # Include JMS Message Properties Field values in the event
  config :include_properties, :validate => :boolean, :default => true

  # List of headers to skip from the event if headers are included
  config :skip_headers, :validate => :array, :default => []

  # List of properties to skip from the event if properties are included
  config :skip_properties, :validate => :array, :default => []

  # Include JMS Message Body in the event
  # Supports TextMessage, MapMessage and ByteMessage
  # If the JMS Message is a TextMessage or ByteMessage, then the value will be in the "message" field of the event
  # If the JMS Message is a MapMessage, then all the key/value pairs will be added in the Hashmap of the event
  # StreamMessage and ObjectMessage are not supported

  # Receive Oracle AQ buffered messages.
  # In this mode persistent Oracle AQ JMS messages will not be received.
  config :oracle_aq_buffered_messages, :validate => :boolean, :default => false

  config :include_body, :validate => :boolean, :default => true

  # Convert the JMSTimestamp header field to the @timestamp value of the event
  config :use_jms_timestamp, :validate => :boolean, :default => false

  # Choose an implementation of the run block. Value can be either consumer, async or thread
  config :runner, :deprecated => true

  # Set the selector to use to get messages off the queue or topic
  config :selector, :validate => :string

  # Initial connection timeout in seconds.
  config :timeout, :validate => :number, :default => 60

  # Polling interval in seconds.
  config :interval, :validate => :number, :default => 10

  # If pub-sub (topic) style should be used.
  config :pub_sub, :validate => :boolean, :default => false

  # Durable message_consumer settings.
  # By default the `durable_subscriber_name` will be set to the topic, and `durable_subscriber_client_id` will be set
  # to 'Logstash'
  config :durable_subscriber, :validate => :boolean, :default => false
  config :durable_subscriber_client_id, :validate => :string, :required => false
  config :durable_subscriber_name, :validate => :string, :required => false

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
  config :password, :validate => :password
  # Url to use when connecting to the JMS provider
  config :broker_url, :validate => :string

  # Name of JNDI entry at which the Factory can be found
  config :jndi_name, :validate => :string
  # Mandatory if jndi lookup is being used,
  # contains details on how to connect to JNDI server
  config :jndi_context, :validate => :hash

  # System properties
  config :system_properties, :validate => :hash

  # Factory settings
  config :factory_settings, :validate => :hash

  config :keystore, :validate => :path
  config :keystore_password, :validate => :password
  config :truststore, :validate => :path
  config :truststore_password, :validate => :password

  # Defines a target field for placing fields.
  # If this setting is omitted, data gets stored at the root (top level) of the event.
  # The target is only relevant while decoding data into a new event.
  #
  # NOTE: this is only relevant for map messages; byte[] and string use the codec!
  config :target, :validate => :field_reference

  config :headers_target, :validate => :field_reference # ECS default: [@metadata][input][jms][headers]
  config :properties_target, :validate => :field_reference # ECS default: [@metadata][input][jms][properties]

  # :yaml_file, :factory and :jndi_name are mutually exclusive, both cannot be supplied at the
  # same time. The priority order is :yaml_file, then :jndi_name, then :factory
  #
  # JMS Provider specific properties can be set if the JMS Factory itself
  # has setters for those properties.
  #
  # For some known examples, see: [Example jms.yml](https://github.com/reidmorrison/jruby-jms/blob/master/examples/jms.yml)

  public

  def initialize(*params)
    super

    if ecs_compatibility != :disabled # set ECS target defaults
      @headers_target = '[@metadata][input][jms][headers]' unless original_params.include?('headers_target')
      @properties_target = '[@metadata][input][jms][properties]' unless original_params.include?('properties_target')
    end

    @headers_setter = event_setter_for(@headers_target)
    @properties_setter = event_setter_for(@properties_target)

    @headers_mapper = ecs_compatibility == :disabled ? LegacyHeadersMapper::INSTANCE : HeadersMapper::INSTANCE
  end

  def register
    require "jms"

    check_config!
    load_ssl_properties
    load_system_properties if @system_properties
    @jms_config = jms_config

    @logger.debug("JMS Config being used ", :context => obfuscate_jms_config(@jms_config))
  end # def register

  def obfuscate_jms_config(config)
    config.each_with_object({}) { |(k, v), h| h[k] = obfuscatable?(k) ? 'xxxxx' : v }
  end

  def obfuscatable?(setting)
    [:password, :keystore_password, :truststore_password].include?(setting)
  end

  def jms_config
    return jms_config_from_yaml(@yaml_file, @yaml_section) if @yaml_file
    return jms_config_from_jndi if @jndi_name
    jms_config_from_configuration
  end


  def jms_config_from_configuration
    config = {
        :require_jars => @require_jars,
        :factory => @factory,
        :username => @username,
        :broker_url => @broker_url,
        :url => @broker_url # "broker_url" is named "url" with Oracle AQ
    }

    config[:password] = @password.value unless @password.nil?
    correct_factory_hash(config, @factory_settings) unless @factory_settings.nil?
    config
  end

  def correct_factory_hash(original, value)
    if hash.is_a?(String)
      return true if value.downcase == "true"
      return false if value.downcase == "false"
    end

    if value.is_a?(Hash)
      value.each { |key, value| original[key.to_sym] = correct_factory_hash({}, value) }
      return original
    end
    value
  end

  def jms_config_from_jndi
    {
        :require_jars => @require_jars,
        :jndi_name => @jndi_name,
        :jndi_context => @jndi_context
    }
  end

  def jms_config_from_yaml(file, section)
    YAML.load_file(file)[section]
  end

  def load_ssl_properties
    java.lang.System.setProperty("javax.net.ssl.keyStore", @keystore) if @keystore
    java.lang.System.setProperty("javax.net.ssl.keyStorePassword", @keystore_password.value) if @keystore_password
    java.lang.System.setProperty("javax.net.ssl.trustStore", @truststore) if @truststore
    java.lang.System.setProperty("javax.net.ssl.trustStorePassword", @truststore_password.value) if @truststore_password
  end

  def load_system_properties
    @system_properties.each { |k,v| java.lang.System.set_property(k,v.to_s) }
  end

  def check_config!
    if original_params.include?('include_header')
      if original_params.include?('include_headers')
        raise(LogStash::ConfigurationError, "Both `include_headers => #{include_headers}` and `include_header => #{include_header}`" +
                                            " options are specified, please only set one")
      end
      @include_headers = include_header # only `include_header => ...` was set
    end

    check_durable_subscription_config
    raise(LogStash::ConfigurationError, "Threads cannot be > 1 if pub_sub is set") if @threads > 1 && @pub_sub
  end

  def check_durable_subscription_config
    return unless @durable_subscriber
    raise(LogStash::ConfigurationError, "pub_sub must be true if durable_subscriber is set") unless @pub_sub
    @durable_subscriber_client_id ||= 'Logstash'
    @durable_subscriber_name ||= destination
  end

  def run(output_queue)
    begin
      connection = JMS::Connection.new(@jms_config)
      connection.client_id = @durable_subscriber_client_id if @durable_subscriber_client_id
      session = connection.create_session(@jms_config)
      connection.start
      params = {:timeout => @timeout * 1000, :selector => @selector}
      subscriber = subscriber(session, params)
      until stop?
        # read from the queue/topic until :timeout is reached, or a message is available
        # (whichever comes first)
        do_receive_message(subscriber, timeout: @interval * 1000) do |message|
          queue_event(message, output_queue)
          break if stop?
        end
      end
    rescue => e
      logger.warn("JMS Consumer Died", error_hash(e))
      unless stop?
        sleep(5)
        subscriber && subscriber.close
        session && session.close
        connection && connection.close
        retry
      end
    ensure
      subscriber && subscriber.close
      session && session.close
      connection && connection.close
    end
  end # def run_consumer

  def queue_event(msg, output_queue)
    begin
      if @include_body
        if msg.kind_of?(JMS::MapMessage)
          event = process_map_message(msg)
        elsif msg.kind_of?(JMS::TextMessage) || msg.kind_of?(JMS::BytesMessage)
          event = decode_message(msg)
        else
          @logger.error( "Unsupported message type #{msg.data.class.to_s}" )
        end
      end

      event ||= event_factory.new_event

      # Here, we can use the JMS Enqueue timestamp as the @timestamp
      if @use_jms_timestamp && msg.jms_timestamp
        event.set("@timestamp", LogStash::Timestamp.at(msg.jms_timestamp / 1000, (msg.jms_timestamp % 1000) * 1000))
      end

      if @include_headers
        headers = map_headers(msg)
        @skip_headers.each { |key| headers.delete(key) }
        @headers_setter.call(event, headers)
      end

      if @include_properties
        properties = to_string_keyed_hash(msg.properties)
        @skip_properties.each { |key| properties.delete(key) }
        @properties_setter.call(event, properties)
      end

      decorate(event)
      output_queue << event

    rescue => e # parse or event creation error
      @logger.error("Failed to create event", :message => msg, :exception => e,
                    :backtrace => e.backtrace)
    end
  end

  # Loop through messages received and yield them.
  #
  # NOTE: a simplified replacement for JMS::MessageConsumer#each and #get (extensions).
  #
  # @param message_consumer [javax.jms.MessageConsumer]
  # @param timeout in milliseconds
  def do_receive_message(message_consumer, timeout: 0)
    # Receive messages according to timeout
    while true
      case timeout
      when  0 # Return immediately if no message is available
        message = message_consumer.receiveNoWait()
      when -1 # Wait forever
        message = message_consumer.receive()
      else # Wait for x milli-seconds for a message to be received from the broker
        message = message_consumer.receive(timeout)
      end
      break unless message
      yield message
    end
  end

  def to_string_keyed_hash(hash)
    hash.inject({}) { |h, (key, val)| h[key.to_s] = val; h }
  end
  private :to_string_keyed_hash

  # @param msg [JMS::MapMessage]
  # @return [LogStash::Event]
  def process_map_message(msg)
    data = to_string_keyed_hash(msg.data)
    do_target_check_once_and_get_event_factory.new_event(data)
  end

  def do_target_check_once_and_get_event_factory
    @target_checked ||= begin
                          do_target_check
                          targeted_event_factory
                        end
  end

  TARGET_NOT_SET_MESSAGE = LogStash::PluginMixins::ECSCompatibilitySupport::TargetCheck::TARGET_NOT_SET_MESSAGE

  def do_target_check
    return true unless target.nil?
    return nil if ecs_compatibility == :disabled
    logger.info(TARGET_NOT_SET_MESSAGE) # target isn't set in ECS mode
  end

  # @param msg [JMS::TextMessage, JMS::BytesMessage]
  # @return [LogStash::Event, nil]
  def decode_message(msg)
    text = msg.to_s # javax.jms.TextMessage#getText (e.g. JSON payload)
    event = nil
    @codec.decode(text) { |e| event = e } unless text.nil?
    event
  end

  def subscriber(session, params)
    destination_key = @pub_sub ? :topic_name : :queue_name
    params[destination_key] = @destination
    queue_or_topic = session.create_destination(params)
    @durable_subscriber ? durable_subscriber(session, queue_or_topic, params) :
                          regular_subscriber(session, queue_or_topic, params)
  end


  def durable_subscriber(session, queue_or_topic, params)
    params[:selector]  ? session.create_durable_subscriber(queue_or_topic, @durable_subscriber_name, params[:selector], false) :
                         session.create_durable_subscriber(queue_or_topic, @durable_subscriber_name)
  end

  def regular_subscriber(session, queue_or_topic, params)
    params[:selector] ? session.create_consumer(queue_or_topic, params[:selector]) :
                        session.create_consumer(queue_or_topic)
  end

  def error_hash(e)
    error_hash = {:exception => e.class.name, :exception_message => e.message, :backtrace => e.backtrace}
    root_cause = get_root_cause(e)
    error_hash[:root_cause] = root_cause unless root_cause.nil?
    error_hash
  end

  # JMS Exceptions can contain chains of Exceptions, making it difficult to determine the root cause of an error
  # without knowing the actual root cause behind the problem.
  # This method protects against Java Exceptions where the cause methods loop. If there is a cause loop, the last
  # cause exception before the loop is detected will be returned, along with an entry in the root_cause hash indicating
  # that an exception loop was detected. This will mean that the root cause may not be the actual root cause of the
  # problem, and further investigation is required
  def get_root_cause(e)
    return nil unless e.respond_to?(:get_cause) && !e.get_cause.nil?
    cause = e
    slow_pointer = e
    # Use a slow pointer to avoid cause loops in Java Exceptions
    move_slow = false
    until (next_cause = cause.get_cause).nil?
      cause = next_cause
      return {:exception => cause.class.name, :exception_message => cause.message, :exception_loop => true } if cause == slow_pointer
      slow_pointer = slow_pointer.cause if move_slow
      move_slow = !move_slow
    end
    {:exception => cause.class.name, :exception_message => cause.message }
  end

  private

  def normalize_field_ref(target)
    # so we can later event.set("#{target}[#{name}]", ...)
    target.match?(/\A[^\[\]]+\z/) ? "[#{target}]" : target
  end

  def event_setter_for(target)
    if target.nil? || target.empty?
      TOP_LEVEL_EVENT_SETTER
    else
      TargetEventSetter.new normalize_field_ref(target)
    end
  end

  TOP_LEVEL_EVENT_SETTER = lambda { |event, data| data.each { |key, val| event.set(key, val) } }
  private_constant :TOP_LEVEL_EVENT_SETTER

  class TargetEventSetter

    def initialize(target)
      @target = target
    end

    def call(event, data)
      data.each { |key, val| event.set("#{@target}[#{key}]", val) }
    end

  end
  private_constant :TargetEventSetter

  def map_headers(msg)
    @headers_mapper.call(msg)
  end

  # Maps JMS headers names
  # (similar to JMS gem's Message#attributes extension)
  class HeadersMapper

    # @param msg [javax.jms.Message]
    # @return [Hash]
    def call(msg)
      map = {
        'jms_message_id' => msg.getJMSMessageID, # String
        'jms_timestamp' => msg.getJMSTimestamp, # long
        'jms_expiration' => msg.getJMSExpiration, # long
        'jms_priority' => msg.getJMSPriority, # int (0-9)
        'jms_type' => msg.getJMSType, # String
        'jms_redelivered' => msg.getJMSRedelivered, # boolean
      }

      correlation_id = msg.getJMSCorrelationID # String
      map['jms_correlation_id'] = correlation_id unless correlation_id.nil?

      delivery_mode = jms_delivery_mode(msg)
      map['jms_delivery_mode'] = delivery_mode unless delivery_mode.nil?

      destination = msg.getJMSDestination # javax.jms.Destination
      map['jms_destination'] = destination.to_string unless destination.nil?

      reply_to = msg.getJMSReplyTo # javax.jms.Destination
      map['jms_reply_to'] = reply_to.to_string unless reply_to.nil?

      map
    end

    private

    def jms_delivery_mode(msg)
      case msg.getJMSDeliveryMode
      when javax.jms.DeliveryMode::PERSISTENT
        'persistent'
      when javax.jms.DeliveryMode::NON_PERSISTENT
        'non_persistent'
      else
        nil
      end
    end

    INSTANCE = self.new

  end

  # For plugin compatibility due the use of JMS gem's Message#attributes.
  class LegacyHeadersMapper < HeadersMapper

    def call(msg)
      map = super(msg)
      delivery_mode = jms_delivery_mode(msg)
      map['jms_delivery_mode_sym'] = delivery_mode ? delivery_mode.to_sym : nil
      map
    end

    INSTANCE = self.new

  end

end # class LogStash::Inputs::Jms
