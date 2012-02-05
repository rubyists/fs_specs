Feature: Channel can interact with voicemail
  In order to utilize voicemail
  As a channel
  I want to be able to log into, and use, the voicemail system

  Background: 
    Given I have 2 servers named localhost and tigershark.rubyists.com
    And localhost is accessible via the Event Socket

    Scenario: Successfully log into voicemail using extension
      And I dial into voicemail using extension "4000"
      And I am prompted for my extension and password
      And I supply my extension and password
      Then I should be logged into voicemail
      And I should be able to terminate all calls

    Scenario: Fail to log into voicemail using extension
      And I dial into voicemail using extension "4000"
      And I am prompted for my extension and password
      And I supply an incorrect extension and password
	    Then I should be prompted to try again
		
	  Scenario: Successfully log into voicemail using shortcut
      And I dial into voicemail using extension "*98"
	    And I supply my extension and password
	    Then I should be logged into voicemail

		Scenario: Fail to log into voicemail using shortcut
      And I dial into voicemail using extension "*98"
			And I supply an incorrect extension and password
		  Then I should be prompted to try again

