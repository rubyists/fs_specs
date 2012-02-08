require './helpers'

require 'yaml'
require 'rspec/autorun'

require File.dirname(__FILE__) + "/custom_matchers"

Spec::Runner.configure do |config|
  config.include(CustomMatcher)
end

