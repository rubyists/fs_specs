Feature: Can receive channel event data of current call

  Background: 
    Given I have 2 servers named blackbird.rubyists.com and tigershark.rubyists.com
    And blackbird.rubyists.com is accessible via the Event Socket

  Scenario:
    When I dial extension "9192" on tigershark.rubyists.com
    Then I should be connected to that extension
    And I should be able to access channel data
