When /^I make a phone call$/ do
  orig = @sock.originate(target: "sofia/external/3000@#{@server2}", endpoint: '&transfer(9664)')
  @uuid = orig.run(:api)['body'].split[1]

  # Due to asyncronous nature of the entire method chain
  # which involves network stack, call plans, etc..
  # We sleep long enough for the call creations have been handled _throughout_ the stack.
  # We limit our sleep times to < 1s in order to wait the last amount of time,
  # and include additional checks oside the sleep to limit wait time further.
  30.times do
    sleep 0.1
    break if @sock.calls.run.any?{|call| call.uuid == @uuid }
  end
  our_call = @sock.calls.run.detect { |call| call.uuid == @uuid }
  fail "No Call Exists!" unless our_call and our_call.uuid == @uuid
end

Given /^I have 2 servers named ([\w.]+) and ([\w.]+)$/ do |server1, server2|
  @server1, @server2 = server1, server2
  @sock = FSR::CommandSocket.new(server: @server1, port: 8021)
end

Then /^I should be able to terminate the call$/ do
  fail "I Have no UUID!" if @uuid.nil?
  resp = @sock.kill(@uuid).run(:api)
  fail "Response #{resp} was not OK" unless resp["body"].match /^\+OK/
  30.times do
    sleep 0.1
    break unless @sock.calls.run.detect { |c| c.uuid == @uuid }
  end
  # This is failing for phone_infrastructure
  fail "Call not terminated!" unless @sock.calls.run.detect { |c| c.uuid == @uuid } == nil
end

Then /^I should be able to terminate all calls$/ do
  @sock.calls.run.each do |call|
    @sock.say("api uuid_kill #{call.uuid}")
  end

  # Due to asynchronous nature of the entire method chain
  # which involves network stack, call plans, etc..
  # We wait until all call deletions have caught up to us.
  30.times do
    sleep 0.1
    break unless @sock.calls.run.size > 0
  end
  fail unless @sock.calls.run.size == 0
end

Given /^([\w.]+) is accessible via the Event Socket$/ do |es_server|
  @sock = FSR::CommandSocket.new(server: @server1)
  fail if @sock.nil?
end

Given /^I am known to FreeSWITCH$/ do
  steps %{
    When I make a phone call
  }
end

Given /^I have a conference object$/ do
  @confs = @sock.conference(:list).run
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
  fail "No endpoint created" unless orig = @sock.originate(target: 'sofia/external/%s@%s' % [known_extension, @server2],
                         endpoint: "&transfer('3000 XML default')")
  @resp = orig.run(:api)
  fail "Response does not contain OK" unless (@resp["body"].match /^\+OK \w{8}-(?:\w{4}-){3}\w{12}$/)
end

And /^I dial into voicemail using extension "([^"]*)"$/ do |vm_extension|
  # Create connection to extension 4000 OR '*98' for voicemail access
  fail "No endpoint created" unless orig = @sock.originate(target: 'sofia/external/%s@%s' % [vm_extension, @server2],
                  endpoint: "&transfer('#{vm_extension} XML default')")
  # Store the response
  resp = orig.run(:api)
  fail "Unable to connect to voicemail" unless (resp["body"].match /^\+OK /)
  @uuid = resp["body"].split[1] # This should have the uuid It's what I was trying to see.
  # We use @uuid in further steps
end

Then /^I should be connected to that extension$/ do
  message, @uuid = @resp["body"].split(" ")
  fail "No UUID found" unless message == '+OK'
end

When /^I dial unknown extension "([^"]*)"$/ do | unknown_extension|
  orig = @sock.originate(target: 'sofia/external/%s@%s' % [unknown_extension, @server2],
                         endpoint: "&transfer('3000 XML default')")
  @resp = orig.run(:api)
  fail "Previous command did not generate an error" unless @resp["body"].match /^-ERR/
end

Then /^I should be notified the call failed$/ do
  status, @message = @resp["body"].split(" ")
  fail unless status == '-ERR'
end

Then /^I should recieve call failure type "([^"]*)"$/ do |failure_type|
  fail unless @message == "#{failure_type}"
end

When /^I am prompted for my extension and password$/ do
  # Here we do the em run, we can do one per step for now
  # TODO: Make a listener class for this
  $stdout.sync = true # always flush after

  EM.run do
    # Wait 60 seconds for a voicemail prompt - This is only due to travis-ci to ensure we have enough time.
    EM.add_periodic_timer(60) { |e| fail "Timed out waiting to get voicemail prompt"; EM.stop }

    listener = Class.new(FSL::Inbound){

      def before_session
        # subscribe to events
        add_event(:ALL){|event| on_event(event) }
      end

      def on_event(event)
        # are you not seeing these?
        #
        # It looks like in both checks on the playback_file we get either of these 4.
        #   /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav
        #  file_string://ascii/35.wav for '#' key
        #  /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav after failure to authenticate vm_extension+vm_password pairs
        #  /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav upon FS drop/destroy of call
        #
        vm_extension = "1000#"
        vm_password = "1000#"

        expected_playback_file = {
          :enter_id => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav",
          :enter_pass => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav",
          :pound => "file_string://ascii/35.wav",
          :abort => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav",
          :goodbye => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav",
          :press => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
          :logged_in => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_messages.wav"
        }

        #  What seems to be happening is the wav files are cycling play status within the timeframe of the checks. (Reprompt cycling)
        #  This is making this pass *and* fail. If we catch the order right, we pass. we don't, we fail.
        if event.content[:event_name] == "PLAYBACK_START"
          fs_playback_file = event.content[:playback_file_path]
          fail "Wrong file played: #{fs_playback_file}" if event.content[:playback_file_path] == "#{expected_playback_file[:abort]}"
        else
            if event.content[:playback_file_path] == expected_playback_file[:pound]
              puts "Got '#' wav file! - Should send the vm_extension here, inside #{Thread.current}"
              puts "EM.stop is called next because we exit the else, but THIS is the physical location where we need to send the tones for the extension"
              puts "EVENT_NAME: #{event.content[:event_name]} - PLAYBACK_FILE_PATH: #{event.content[:playback_file_path]}"
            end
            # This fails IN the run because @sock is nilClass, meaning its not being passed in correctly
            # so the call to vm_extension fails, which means we can't extend the logic to look for vm-enter_pass.wav
            @sock.uuid_send_dtmf(uuid: @uuid, dtmf: vm_extension)
        end

          # We process on pound above because it denotes expectation change. If
        EM.stop
      end
    }

    # - This needs to be done IN the listener's thread: @sock.uuid_send_dtmf(uuid: @uuid, dtmf: vm_extension)
    EM.connect(@server2, 8021, listener)
  end
end

When /^I supply my extension and password$/ do
  # Configure extension and pass, as well as expected wav files.
  vm_extension = "1000#"
  vm_password = "1000"

  # Start the actual work
  EM.run do
    # Wait 60 seconds for response to dtmf input
    EM.add_periodic_timer(60) { |e| fail "Timed out waiting to get voicemail prompt"; EM.stop }

    listener = Class.new(FSL::Inbound){
    def before_session
        # subscribe to events
        add_event(:ALL){|event| on_event(event) }
      end

      def on_event(event)
        # are you not seeing these?
        expected_playback_file = { :enter_id => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav", :pound => "file_string://ascii/35.wav" }

        if event.content[:event_name] == "PLAYBACK_START"
        fs_playback_file = event.content[:playback_file_path]
        pp fs_playback_file
        fail "Wrong file played: #{fs_playback_file}" unless event.content[:playback_file_path] == "#{expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{expected_playback_file[:pound]}"
          EM.stop
        end
      end
    }
    # BROKEN: We're just being prompted over and over for the extension
    # even after the test fails. So we need to check for a response to uuid_send_dtf
    # and that FS has actually processed it!
    @sock.uuid_send_dtmf(uuid: @uuid, dtmf: vm_extension)
    EM.connect(@server2, 8021, listener)
  end

  EM.run do
    # Wait 60 seconds for response to dtmf input
    EM.add_periodic_timer(60) { |e| fail "Timed out waiting on password confirmation"; EM.stop }
    listener2 = Class.new(FSL::Inbound){
      def before_session
        # subscribe to events
        add_event(:ALL){|event| on_event(event) }
      end

      def on_event(event)
        # are you not seeing these?
        expected_playback_file = { :enter_id => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav", :pound => "file_string://ascii/35.wav" }

        if event.content[:event_name] == "PLAYBACK_START"
          fs_playback_file = event.content[:playback_file_path]
          pp fs_playback_file
          fail "Wrong file played: #{fs_playback_file}" unless event.content[:playback_file_path] == "#{expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{expected_playback_file[:pound]}"
          EM.stop
        end
      end
    }
    # BROKEN: Not currently seeing /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav
    # requested. I don't think we're successfully completing passing the extension in order to get 'here'
    # to even be offered vm-enter_pass.wav
    @sock.uuid_send_dtmf(uuid: @uuid, dtmf: vm_password)
    EM.connect(@server2, 8021, listener2)
  end
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

