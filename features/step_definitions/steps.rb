Then /^true.should == true$/ do
       true.should == true
end

Then /^false.should != true$/ do
  false.should_not == true
end

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
  @sock.calls.run.size.should == 0

end

Given /^([\w.]+) is accessible via the Event Socket$/ do |es_server|
  @sock = FSR::CommandSocket.new(server: @server1)
  @sock.should_not be_nil
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
  orig = @sock.originate(target: 'sofia/external/%s@%s' % [known_extension, @server2], endpoint: "&transfer('3000 XML default')")
  orig.should_not be_nil

  @resp = orig.run(:api)
  fail "Response does not contain OK" unless (@resp["body"].match /^\+OK \w{8}-(?:\w{4}-){3}\w{12}$/)
end

When /^I dial into voicemail using extension "([^"]*)"$/ do |vm_extension|
  # Create connection to extension 4000 OR '*98' for voicemail access
  orig = @sock.originate(target: 'sofia/external/%s@%s' % [vm_extension, @server2], endpoint: "&transfer('#{vm_extension} XML default')")
  orig.should_not be_nil

  # Store the response
  resp = orig.run(:api)

  resp["body"].should match(/^\+OK /)

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

  @resp["body"].should match(/^-ERR/)

end

Then /^I should be notified the call failed$/ do
  status, @message = @resp["body"].split(" ")
  status.should match('-ERR')

end

Then /^I should recieve call failure type "([^"]*)"$/ do |failure_type|
  @message.should match("#{failure_type}")
end

When /^I am prompted for my extension and password$/ do
  $stdout.sync = true # always flush after

  EM.run do
    # Inside EM.run block so this is operating full speed and live on the listener sockets we create in here.
    # Wait 10 seconds for a voicemail prompt - This is only due to travis-ci to ensure we have enough time.
    #
    EM.add_periodic_timer(10) { |e| fail "Timed out waiting to get voicemail prompt"; EM.stop }

    listener1 = Class.new(FSL::Inbound){

      def before_session
        # subscribe to events
        add_event(:ALL){|event| on_event(event) }
      end

      def on_event(event)
        # It looks like in both checks on the playback_file we get either of these 4.
        #   /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav
        #  file_string://ascii/35.wav for '#' key
        #  /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav after failure to authenticate vm_extension+vm_password pairs
        #  /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav upon FS drop/destroy of call

        expected_playback_file = {
          :enter_id => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav",
          :enter_pass => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav",
          :pound => "file_string://ascii/35.wav",
          :abort => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav",
          :goodbye => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav",
          :press => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
          :logged_in => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_messages.wav"
        }

        case event.content[:event_name]
        	when "CHANNEL_EXECUTE_COMPLETE", "CHANNEL_EXECUTE", "HEARTBEAT", "RE_SCHEDULE"

        	when "PLAYBACK_START"
            fail "We got vm-abort.wav!" if event.content[:playback_file_path] == expected_playback_file[:abort]

            if event.content[:playback_file_path] == "#{expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{expected_playback_file[:pound]}"
              puts "SUCCEEDED! WE WERE PROMPTED - Got #{event.content[:playback_file_path]}"
              return 0
            end

            fs_playback_file = event.content[:playback_file_path]
        	  puts "PROMPTED - 1 EM.run - #{Thread.current.to_s} - event.content[:event_name] = #{event.content[:event_name]} fs_playback_file: #{fs_playback_file}"

        	when "PLAYBACK_STOP"
            if event.content[:playback_file_path] == "#{expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{expected_playback_file[:pound]}"
              puts "SUCCEEDED! WE WERE PROMPTED - Got #{event.content[:playback_file_path]}"
              return 0
            else
              fs_playback_file = event.content[:playback_file_path]
        	    puts "PROMPTED - 1 EM.run - #{Thread.current.to_s} - event.content[:event_name] = #{event.content[:event_name]} fs_playback_file: #{fs_playback_file}"
            end

        	when nil
        	  puts "In 1st EM.run 'case' - event.content[:event_name] is nil"
        	  return

        	else
            fail "Wrong file played: #{fs_playback_file}" unless event.content[:playback_file_path] == "#{expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{expected_playback_file[:pound]}"
        end
        EM.stop
      end
    }
    EM.connect(@server2, 8021, listener1)
  end
end

When /^I supply my extension and password$/ do
  # Configure extension and pass, as well as expected wav files.
  vm_extension = "1000#"
  vm_password = "1000"

  # Start the actual work
  EM.run do
    # Wait 10 seconds for response to dtmf input
    EM.add_periodic_timer(10) { |e| fail "Timed out waiting to get voicemail prompt"; EM.stop }

    listener2 = Class.new(FSL::Inbound){
      def before_session
        # subscribe to events
        add_event(:ALL){|event| on_event(event) }
      end

      def on_event(event)
        # are you not seeing these?
        expected_playback_file = {
          :enter_id => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav",
          :enter_pass => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav",
          :pound => "file_string://ascii/35.wav",
          :abort => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav",
          :goodbye => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav",
          :press => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
          :logged_in => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_messages.wav"
        }

        #sleep(1)

        case event.content[:event_name]
        	when "CHANNEL_EXECUTE_COMPLETE", "CHANNEL_EXECUTE", "HEARTBEAT", "RE_SCHEDULE"
        	  puts "SUPPLY - 1 EM.run - #{Thread.current.to_s} - CHANNEL MANAGEMENT : event.content[:event_name] = #{event.content[:event_name]}"

        	when "PLAYBACK_START"
            fail "We got vm-abort.wav!" if event.content[:playback_file_path] == expected_playback_file[:abort]
        	  fs_playback_file = event.content[:playback_file_path]
        	  puts "SUPPLY - 1 EM.run - #{Thread.current.to_s} - event.content[:event_name] = #{event.content[:event_name]} fs_playback_file: #{fs_playback_file}"

        	when "PLAYBACK_STOP"
        	  fs_playback_file = event.content[:playback_file_path]
        	  puts "SUPPLY - 1 EM.run - #{Thread.current.to_s} - event.content[:event_name] = #{event.content[:event_name]} fs_playback_file: #{fs_playback_file}"

        	when nil
        	  puts "In 1st EM.run 'case' - event.content[:event_name] is nil"
        	  return

        	else
        	  fs_playback_file = event.content[:playback_file_path]
        	  puts "In 1st EM.run 'case' - else hit! - SUPPLY - #{Thread.current.to_s}"
            puts "In 1st EM.run 'case' - Supply Extension/Password: EVENT_NAME: #{event.content[:event_name]} - PLAYBACK_FILE: #{fs_playback_file}"
            fail "Not 'Enter ID' or 'Pound'. Wrong file played: #{fs_playback_file}" unless event.content[:playback_file_path] == "#{expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{expected_playback_file[:pound]}"
        end
        EM.stop
      end
    }
    # BROKEN: We're just being prompted over and over for the extension
    # even after the test fails. So we need to check for a response to uuid_send_dtmf
    # and that FS has actually processed it! Looking on both switch, that DTMF send is never seen.
    @sock.uuid_send_dtmf(uuid: @uuid, dtmf: vm_extension)
    EM.connect(@server2, 8021, listener2)
  end

  EM.run do
    # Wait 10 seconds for response to dtmf input
    EM.add_periodic_timer(10) { |e| fail "Timed out waiting on password confirmation"; EM.stop }
    listener2 = Class.new(FSL::Inbound){
      def before_session
        # subscribe to events
        add_event(:ALL){|event| on_event(event) }
      end

      def on_event(event)
        # are you not seeing these?
        expected_playback_file = {
          :enter_id => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav",
          :enter_pass => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav",
          :pound => "file_string://ascii/35.wav",
          :abort => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav",
          :goodbye => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav",
          :press => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
          :logged_in => "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_messages.wav"
        }

        #sleep(1)

        case event.content[:event_name]
        	when "CHANNEL_EXECUTE_COMPLETE", "CHANNEL_EXECUTE", "HEARTBEAT", "RE_SCHEDULE"
        	  puts "SUPPLY - 2 EM.run - CHANNEL MANAGEMENT : event.content[:event_name] = #{event.content[:event_name]}"

        	when "PLAYBACK_START"
            fail "We got vm-abort.wav!" if event.content[:playback_file_path] == expected_playback_file[:abort]

        	  fs_playback_file = event.content[:playback_file_path]
        	  puts "SUPPLY - 2 EM.run - #{Thread.current.to_s} - event.content[:event_name] = #{event.content[:event_name]} fs_playback_file: #{fs_playback_file}"

        	when "PLAYBACK_STOP"
        	  fs_playback_file = event.content[:playback_file_path]
        	  puts "SUPPLY - 2 EM.run - #{Thread.current.to_s} - event.content[:event_name] = #{event.content[:event_name]} fs_playback_file: #{fs_playback_file}"

        	when nil
        	  puts "In 2nd EM.run 'case' - event.content[:event_name] is nil"
        	  return

        	else
        	  fs_playback_file = event.content[:playback_file_path]
            fail "Wrong file played: #{fs_playback_file}" unless event.content[:playback_file_path] == "#{expected_playback_file[:enter_id]}" || event.content[:playback_file_path] == "#{expected_playback_file[:pound]}"
        	  puts "In 2nd EM.run 'case' - else hit!"
        end
          EM.stop
      end
    }
    # BROKEN: Not currently seeing /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav
    # requested. I don't think we're successfully completing passing the extension in order to get 'here'
    # to even be offered vm-enter_pass.wav
    vm_password = "1000#"

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
