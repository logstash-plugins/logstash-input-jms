Gem::Specification.new do |s|

  s.name            = 'logstash-input-jms'
  s.version         = '2.0.3'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = "Pull events from a JMS topic or queue."
  s.description     = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ["Elasticsearch"]
  s.email           = 'info@elasticsearch.com'
  s.homepage        = "http://www.elasticsearch.org/guide/en/logstash/current/index.html"
  s.require_paths = ["lib"]

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", ">= 2.0.0", "< 6.0.0.alpha1"

  s.add_runtime_dependency 'logstash-codec-json'
  s.add_runtime_dependency 'logstash-codec-plain'

  if RUBY_PLATFORM == 'java'
    s.platform = RUBY_PLATFORM
    s.add_runtime_dependency "jruby-jms", ">= 1.2.0" #(Apache 2.0 license)
  end
  s.add_development_dependency 'logstash-devutils'
end
