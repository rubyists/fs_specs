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

  resp = @sock2.kill(@uuid).run(:api)

  resp["body"].should match(/^\+OK/)

  30.times do
    sleep 0.1
    break unless @sock2.calls.run.detect { |c| c.uuid == @uuid }
  end
  # Make sure there are no calls left still dangling
  @sock2.calls.run.detect { |c| c.uuid == @uuid }.should be_nil
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
  @confs = @sock2.conference(:list).run
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

When /^I check voicemail for user (\d+) with good password (\d+)$/ do |vm_extension, vm_password|
  EM.run do
    # Wait 30 seconds for response to dtmf input
    EM.add_periodic_timer(30) { |e| EM.stop }
    EM.connect(@server2, 8021, VmListener, @sock1, @sock2, @server1, @server2, vm_extension, vm_password)
  end
end

When /^I check voicemail for user (\d+) with bad password (\d+)$/ do |vm_extension, vm_password|
  # Configure extension and pass, as well as expected wav files.
    EM.run do
    # Wait 30 seconds for response to dtmf input
    EM.add_periodic_timer(30) { |e| EM.stop }
    EM.connect(@server2, 8021, VmListener, @sock1, @sock2, @server1, @server2, vm_extension, vm_password)
  end
end

Then /^I should be logged into voicemail$/ do
  # BROKEN: Need a way here to *verify* that we have, in fact, had our ext. and pass. accepted,
  # and we get something like /var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_more_messages.wav
  if VmListener::PLAYBACK_FILES.include?(VmListener::SOUNDS[:vm_has_messages])
    VmListener::PLAYBACK_FILES.should == VmListener::SOUNDS.values_at(:vm_enter_id, :pound, :vm_enter_pass, :pound, :vm_has_messages)
  else
    VmListener::PLAYBACK_FILES.should == VmListener::SOUNDS.values_at(:vm_enter_id, :pound, :vm_enter_pass, :pound, :vm_no_messages)
  end
  VmListener::PLAYBACK_FILES.clear
  VmListener::PLAYBACK_FILES.clear
  VmListener::PLAYBACK_FILES.should == []
end

Then /^I should be prompted to try again$/ do
  VmListener::PLAYBACK_FILES.should == VmListener::SOUNDS.values_at(:vm_enter_id, :pound, :vm_enter_pass, :pound, :vm_fail)
  VmListener::PLAYBACK_FILES.clear
  VmListener::PLAYBACK_FILES.should == []
end

When /^I press "([^"]*)"$/ do |key_sequence|
  @key_sequence = key_sequence or fail "We got no key_sequence for generating DTMF presses with!"
end

Then /^I should be able to access event data$/ do
    pending # express the regexp above with the code you wish you had
end

Then /^I should be able to access channel data$/ do
    pending # express the regexp above with the code you wish you had
end
