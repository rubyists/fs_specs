Feature: A channel can dial an extension

  Once a UserAgent (X-Lite, PolyCom, another FS) can successfully connect to freeswitch,
  that UserAgent should be able to place a call to any known extension, and connect.

  If that extension can not be connected to, then the UserAgent should be notified of both 
  the fact of the failure, and the type of the failure. (NoAnswer, UnknownExtension)

  Background: 
    Given I have 2 servers named localhost and falcon.rubyists.com
    And I am known to FreeSWITCH

    Scenario Outline:
      When I dial extension "<known_extension>"
      Then I should be connected to that extension
      And I should be able to terminate the call

    Examples:
      | known_extension |
      | 1000             |
      | 1001             |
      | 1002             |
      | 1003             |
      | 1004             |
      | 1005             |
      | 1006             |
      | 1007             |
      | 1008             |
      | 1009             |
      | 1010             |
      | 1011             |
      | 1012             |
      | 1013             |
      | 1014             |
      | 1015             |
      | 1016             |
      | 1017             |
      | 1018             |
      | 1019             |

    Scenario:
      When I dial unknown extension 1020
      Then I should be notified the call failed
      And I should recieve call failure type FailureType

