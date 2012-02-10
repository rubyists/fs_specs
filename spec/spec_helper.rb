require File.dirname(__FILE__) + "/helpers"

require 'yaml'
require 'rspec/autorun'

require File.dirname(__FILE__) + "/custom_matchers"

RSpec.configure do |config|
  config.include(CustomMatcher)
end

