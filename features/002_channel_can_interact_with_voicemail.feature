Feature: Channel can interact with voicemail
  In order to utilize voicemail
  As a channel
  I want to be able to log into, and use, the voicemail system

  Background:
    Given I have 2 servers named blackbird.rubyists.com and tigershark.rubyists.com
    And blackbird.rubyists.com is accessible via the Event Socket

  Scenario: Successfully log into voicemail using extension
    And I check voicemail for user 1000 with good password 1000
    Then I should be logged into voicemail

  Scenario: Fail to log into voicemail using extension
    And I check voicemail for user 1000 with bad password 1001
    Then I should be prompted to try again

