require 'spec_helper'

module FSSpecs
  class TestRunner
  end
end

describe FSSpecs::TestRunner do
  before(:all) do
    @testrunner = FSSpecs::TestRunner.new
  end

  it "should be false" do
      true.should == false
  end
end

