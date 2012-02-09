Then /^true.should == true$/ do
       true.should == true
end

Then /^false.should != true$/ do
  false.should_not == true
end

Given /^I have 2 servers named ([\w.]+) and ([\w.]+)$/ do |server1, server2|
  @server1, @server2 = server1, server2
  @sock1 = FSR::CommandSocket.new(server: @server1, port: 8021)
  @played_files = []
end

Given /^([\w.]+) is accessible via the Event Socket$/ do |es_server|
  @sock2 = FSR::CommandSocket.new(server: @server1)
  @sock2.should_not be_nil
end

When /^I make a phone call$/ do
  orig = @sock2.originate(target: "sofia/external/3000@#{@server2}", endpoint: '&transfer(9664)')
  @uuid = orig.run(:api)['body'].split[1]

  # Due to asyncronous nature of the entire method chain
  # which involves network stack, call plans, etc..
  # We sleep long enough for the call creations have been handled _throughout_ the stack.
  # We limit our sleep times to < 1s in order to wait the last amount of time,
  # and include additional checks oside the sleep to limit wait time further.
  30.times do
    sleep 0.1
    break if @sock2.calls.run.any?{|call| call.uuid == @uuid }
  end
  our_call = @sock2.calls.run.detect { |call| call.uuid == @uuid }
  fail "No Call Exists!" unless our_call and our_call.uuid == @uuid
end

Then /^I should be able to terminate the call$/ do
  @uuid.should_not be_nil

  resp = @sock.kill(@uuid).run(:api)

  resp["body"].should match(/^\+OK/)

  30.times do
    sleep 0.1
    break unless @sock.calls.run.detect { |c| c.uuid == @uuid }
  end
  # Make sure there are no calls left still dangling
  @sock.calls.run.detect { |c| c.uuid == @uuid }.should be_nil
end

Then /^I should be able to terminate all calls$/ do
  @sock2.calls.run.each do |call|
    @sock2.say("api uuid_kill #{call.uuid}")
  end

  # Due to asynchronous nature of the entire method chain
  # which involves network stack, call plans, etc..
  # We wait until all call deletions have caught up to us.
  30.times do
    sleep 0.1
    break unless @sock2.calls.run.size > 0
  end
  @sock2.calls.run.size.should == 0

end

Given /^I am known to FreeSWITCH$/ do
  steps %{
    When I make a phone call
  }
end

Given /^I have a conference object$/ do
  @confs = @sock.conference(:list).run
  @confs.should_not be_nil
end

When /^I issue command "([^"]*)"$/ do |cmd|
    pending # express the regexp above with the code you wish you had
end

Then /^I should recieve the help text "([^"]*)"$/ do |help_text|
    pending # express the regexp above with the code you wish you had
end

Then /^I should not see an error status$/ do
  pending # express the regexp above with the code you wish you had
end

When /^I dial extension "([^"]*)" on ([\w.]+)$/ do |known_extension, server|
  orig = @sock2.originate(target: 'sofia/external/%s@%s' % [known_extension, @server2], endpoint: "&transfer('3000 XML default')")
  orig.should_not be_nil

  @resp = orig.run(:api)
  fail "Response does not contain OK" unless (@resp["body"].match /^\+OK \w{8}-(?:\w{4}-){3}\w{12}$/)
end

When /^I dial into voicemail using extension "([^"]*)"$/ do |vm_extension|
  # Create connection to extension 4000 OR '*98' for voicemail access
  orig = @sock2.originate(target: 'sofia/external/%s@%s' % [vm_extension, @server2], endpoint: "&transfer('#{vm_extension} XML default')")
  orig.should_not be_nil

  # Store the response
  resp = orig.run(:api)

  resp["body"].should match(/^\+OK /)

  @uuid = resp["body"].split[1] # This should have the uuid It's what I was trying to see.
  # We use @uuid in further steps
  # return @sock2, @uuid
end

Then /^I should be connected to that extension$/ do
  message, @uuid = @resp["body"].split(" ")
  fail "No UUID found" unless message == '+OK'
end

When /^I dial unknown extension "([^"]*)"$/ do | unknown_extension|
  orig = @sock2.originate(target: 'sofia/external/%s@%s' % [unknown_extension, @server2],
                         endpoint: "&transfer('3000 XML default')")
  @resp = orig.run(:api)

  @resp["body"].should match(/^-ERR/)
end

Then /^I should be notified the call failed$/ do
  status, @message = @resp["body"].split(" ")
  status.should match('-ERR')

end

Then /^I should recieve call failure type "([^"]*)"$/ do |failure_type|
  @message.should match("#{failure_type}")
end

When /^I am prompted for and enter my extension and password$/ do
  $stdout.sync = true # always flush after

  EM.run do
    EM.add_timer(10) { |e| fail "Timed out waiting to get voicemail prompt"; EM.stop }

    prompt_listener = Class.new(FSL::Inbound){

      @expected_playback_file = {
        :enter_id => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav",
        :enter_pass => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav",
        :pound => "file_string://ascii/35.wav",
        :abort => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav",
        :goodbye => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav",
        :press => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
        :logged_in => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_messages.wav"
      }

      def before_session
        # subscribe to all events
        add_event(:ALL) { |event| on_event(event) }
      end

      def on_event(event)

        case event.content[:event_name]

        	when nil
        	  puts "In 1st EM.run 'case' - event.content[:event_name] is nil"
        	  return

        	when "CHANNEL_EXECUTE_COMPLETE", "CHANNEL_EXECUTE", "HEARTBEAT", "RE_SCHEDULE"
            # Empty, just processing them out of the list. Lets us process on any channel state as well.

        	when "PLAYBACK_START"
            # Abort early if we see 'vm-abort.wav' or 'vm-goodbye.wav'
            event.content[:playback_file_path].should_not match("#{@expected_playback_file[:abort]}")
            event.content[:playback_file_path].should_not match("#{@expected_playback_file[:goodbye]}")

            # START - If the file is 'vm-enter_id.wav' or 'file_string://ascii/35.wav' for '#' then output we got prompted by the system. Part of the sequence
            # 'return 0' for now until we decide what to do here.
            if event.content[:playback_file_path] == "#{@expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{@expected_playback_file[:pound]}"
              puts "SUCCEEDED! WE WERE PROMPTED - START - Got #{event.content[:playback_file_path]}"
              return 0
            end

        	when "PLAYBACK_STOP"
            # STOP - If the file is 'vm-enter_id.wav' or 'file_string://ascii/35.wav' for '#' then output we got prompted by the system. Part of the sequence
            # 'return 0' for now until we decide what to do here.
            if event.content[:playback_file_path] == "#{expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{expected_playback_file[:pound]}"
              puts "SUCCEEDED! WE WERE PROMPTED - STOP - Got #{event.content[:playback_file_path]}"
              return 0
            end

        	else
            # Empty, just falling through. This will probably change.
        end
      end
      EM.stop # Stop the EM instance
    }

    EM.connect(@server2, 8021, prompt_listener) # Fire off our listener
  end
end

When /^I supply my extension and password$/ do
  # Configure extension and pass, as well as expected wav files.

  # Start the actual work
    # BROKEN: We're just being prompted over and over for the extension
    # even after the test fails. So we need to check for a response to uuid_send_dtmf
    # and that FS has actually processed it! Looking on both switch, that DTMF send is never seen.

  # NOTE: I am sending both at the top of the spec itself here, and again at the end of the EM.run
  $stdout.sync = true
  PLAYBACK_FILES = []
  @expected = {
    vm_enter_id: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav",
    vm_enter_pass: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav",
    pound: "file_string://ascii/35.wav",
    vm_abort: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav",
    vm_goodbye: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav",
    vm_press: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
    vm_logged_in: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_messages.wav"
  }

  EM.run do

    @vm_extension = "1000#"
    @vm_password = "1000#"

    # Wait 10 seconds for response to dtmf input
    EM.add_periodic_timer(10) { |e| EM.stop }
    supply_listener = Class.new(FSL::Inbound){
      # Commented out PLAYBACK_FILES because its already defined higher
      # PLAYBACK_FILES = []
      def before_session
        @expected = {
          vm_enter_id: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav",
          vm_enter_pass: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav",
          pound: "file_string://ascii/35.wav",
          vm_abort: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav",
          vm_goodbye: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav",
          vm_press: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
          vm_logged_in: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_messages.wav"
        }
        # subscribe to events
        add_event(:ALL){|event| on_event(event) }
      end

      def enter_extension
        PLAYBACK_FILES.delete @expected[:pound]
        @sock2.uuid_send_dtmf(uuid: @uuid, dtmf: @vm_extension)
      end

      def enter_password
        PLAYBACK_FILES.delete @expected[:pound]
        @sock2.uuid_send_dtmf(uuid: @uuid, dtmf: @vm_password)
      end

      def on_event(event)
        path = event.content[:playback_file_path]
        enter_extension if(path == @expected[:vm_enter_id] and PLAYBACK_FILES.include?(@expected[:pound]))
        enter_password if(path == @expected[:vm_enter_pass] and PLAYBACK_FILES.include?(@expected[:pound]))
        PLAYBACK_FILES << path
      end
    }
    # BROKEN: Not currently seeing /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav
    # requested. I don't think we're successfully completing passing the extension in order to get 'here'
    # to even be offered vm-enter_pass.wav

    EM.connect(@server2, 8021, supply_listener) do |listener|
      @sock2.uuid_send_dtmf(uuid: @uuid, dtmf: @vm_password)
    end
  end
  #PLAYBACK_FILES.should == @expected.values_at(:vm_enter_id, :vm_enter_pass, :pound, :vm_logged_in)
  PLAYBACK_FILES.should include ("#{@expected[:vm_enter_id]}")
  PLAYBACK_FILES.should include ("#{@expected[:vm_enter_pass]}")
  PLAYBACK_FILES.should include ("#{@expected[:pound]}")

end

Then /^I should be logged into voicemail$/ do
  # BROKEN: Need a way here to *verify* that we have, in fact, had our ext. and pass. accepted,
  # and we get something like /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_more_messages.wav
  pending # express the regexp above with the code you wish you had
end

Given /^I supply an incorrect extension and password$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be prompted to try again$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^I dial shortcut "([^"]*)"$/ do |dialed_shortcut|
  pending # express the regexp above with the code you wish you had
end

When /^I dial extension "([^"]*)"$/ do |extension|
    pending # express the regexp above with the code you wish you had
end

Then /^I should hear the IVR welcome message$/ do
    pending # express the regexp above with the code you wish you had
end

When /^I press "([^"]*)"$/ do |key_sequence|
    pending # express the regexp above with the code you wish you had
end

Then /^I should hear "([^"]*)"$/ do |sound_byte|
    pending # express the regexp above with the code you wish you had
end
