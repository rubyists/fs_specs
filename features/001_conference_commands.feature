Feature: Test all available commands for conferences

  Once a connection has been made to an extension, such as 3000 for conferences,
  we should be able to manage that call using the 'fs_cli' interface. This feature
  tests those commands specific to the 'conference' command.

    Background:
      Given I have 2 servers named localhost and falcon.rubyists.com
      And I have registered to FreeSWITCH

    Scenario Outline: Check command availability
      When I issue command "<Command>"
      Then I should recieve the help text "<Command_Help_Text>"
      But I should not see an error status

    Examples:
    | Command       | Command_Help_Text |
    | help          | help_text         |
    | list          | help_text         |
    | st            | help_text         |
    | xml_list      | help_text         |
    | energy        | help_text         |
    | volume_in     | help_text         |
    | volume_out    | help_text         |
    | play          | help_text         |
    | say           | help_text         |
    | saymember     | help_text         |
    | stop          | help_text         |
    | dtmf          | help_text         |
    | kick          | help_text         |
    | hup           | help_text         |
    | mute          | help_text         |
    | unmute        | help_text         |
    | deaf          | help_text         |
    | undeaf        | help_text         |
    | relate        | help_text         |
    | lock          | help_text         |
    | unlock        | help_text         |
    | agc           | help_text         |
    | dial          | help_text         |
    | bgdial        | help_text         |
    | transfer      | help_text         |
    | record        | help_text         |
    | chkrecord     | help_text         |
    | norecord      | help_text         |
    | exit_sound    | help_text         |
    | enter_sound   | help_text         |
    | pin           | help_text         |
    | nopin         | help_text         |
    | get           | help_text         |
    | set           | help_text         |

  Scenario: Ensure we can terminate the phone call
    Then I should be able to terminate the call
 
