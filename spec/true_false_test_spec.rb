require 'spec_helper'

module FSSpecs
  class TestRunner
  end
end

describe FSSpecs::TestRunner do
  before(:all) do
    @testrunner = FSSpecs::TestRunner.new
  end

  it "true should be true" do
      true.should == true
  end

  it "false should_not be true" do
    false.should_not == true
  end

end

