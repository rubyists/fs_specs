Feature: Establish that phone infrastructure is working

  If we have 2 properly configured freeswitch servers, 
  we want to ensure we can make a connection between the 2 of them,
  and properly terminate that connection.

  Background:
    Given I have 2 servers named 127.0.0.1 and tigershark.rubyists.com 

  Scenario:
    When I make a phone call
    Then I should be able to terminate the call

