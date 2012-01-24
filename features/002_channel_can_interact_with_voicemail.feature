Feature: Channel can interact with voicemail
  In order to utilize voicemail
  As a channel
  I want to be able to log into, and use, the voicemail system

	Background:
		Given I have 2 servers named localhost and falcon.rubyists.com
		And I am known to FreeSWITCH
		
  Scenario: Successfully log into voicemail using extension
  	And I dial extension "4000"
    And I supply my extension and password
		Then I should be logged into voicemail

	Scenario: Fail to log into voicemail using extension
		And I dial extension "4000"
		And I supply an incorrect extension and password
	  Then I should be prompted to try again
		
	  Scenario: Successfully log into voicemail using shortcut
	  	And I dial shortcut "*98"
	    And I supply my extension and password
			Then I should be logged into voicemail

		Scenario: Fail to log into voicemail using extension
			And I dial shortcut "*98"
			And I supply an incorrect extension and password
		  Then I should be prompted to try again
	