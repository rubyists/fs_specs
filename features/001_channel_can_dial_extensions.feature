Feature: A channel can dial an extension
  
  Once a UserAgent (X-Lite, PolyCom, another FS) can successfully connect to freeswitch,
  that UserAgent should be able to place a call to any known extension. The UserAgent should
  be connected to that extension.
  
  If that extension can not be reached, or the extension is not known, then the 
  UserAgent should be notified of both the fact of the failure, and the type of the failure.

  Background: 
    Given I have 2 servers named blackbird.rubyists.com and tigershark.rubyists.com
    And blackbird.rubyists.com is accessible via the Event Socket

  Scenario: 
    When I dial extension "1000" on tigershark.rubyists.com
    Then I should be connected to that extension
    And I should be able to terminate the call

  Scenario: 
    When I dial unknown extension "1020"
    Then I should be notified the call failed
    And I should recieve call failure type "NO_USER_RESPONSE"

