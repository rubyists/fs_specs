Feature: A channel can dial an extension

  Once a UserAgent (X-Lite, PolyCom, another FS) can successfully connect to freeswitch,
  that UserAgent should be able to place a call to any registered extension, and connect.

  If that extension can not be connected to, then the UserAgent should be notified of both 
  the fact of the failure, and the type of the failure. (NoAnswer, UnRegisteredExtension)

  Background: 
    Given I have 2 servers named localhost and falcon.rubyists.com
    Given I have registered to FreeSWITCH

    Scenario:
      When I dial registered extension 1000
      Then I should be connected to that extension

    Scenario:
      When I dial unregistered extension 1000
      Then I should be notified the call failed
      And I should recieve call failure type FailureType

