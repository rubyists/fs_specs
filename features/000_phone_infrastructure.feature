Feature: Establish that phone infrastructure is working
  
  If we have 2 properly configured freeswitch servers, 
  we want to ensure we can make a connection between the 2 of them,
  and properly terminate that connection.

  Background: 
    Given I have 2 servers named blackbird.rubyists.com and tigershark.rubyists.com
    And blackbird.rubyists.com is accessible via the Event Socket

  Scenario: Show that True and False express correctly, and exactly, with should and should_not
    Then true.should == true
    And  false.should != true

  Scenario: 
    When I make a phone call
    Then I should be able to terminate the call

