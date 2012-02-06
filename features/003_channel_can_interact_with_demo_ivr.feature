Feature: Establish that a channel can interact with the IVR system
  
  If we have a properly configured FreeSWITCH, we want to ensure
  we can interact with the Interactive Voice Recognition (IVR) system.
  and then properly terminate that connection.

  Background: 
    Given I have 2 servers named blackbird.rubyists.com and tigershark.rubyists.com
    And blackbird.rubyists.com is accessible via the Event Socket

  Scenario: be able to connect to the IVR system
    When I dial extension "5000" on tigershark.rubyists.com
    Then I should hear the IVR welcome message
    And I should be able to terminate the call

  Scenario: be able to interact with the IVR system
    When I dial extension "5000" on tigershark.rubyists.com
    And I press "5#"
    Then I should hear "screaming monkeys"
    And I should be able to terminate the call

