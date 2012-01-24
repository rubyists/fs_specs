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

Given /^localhost is accessible via the Event Socket$/ do
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

When /^I dial extension "([^"]*)" on falcon.rubyists.com$/ do |known_extension|
  fail "No endpoint created" unless orig = @sock.originate(target: 'sofia/external/%s@%s' % [known_extension, @server2],
                         endpoint: "&transfer('3000 XML default')")
  @resp = orig.run(:api)
  fail "Response does not contain OK" unless (@resp["body"].match /^\+OK \w{8}-(?:\w{4}-){3}\w{12}$/)
end

And /^I dial into voicemail using extension "([^"]*)"$/ do |vm_extension|
  # Create connection to extension 4000 OR '*98' for voicemail access
  fail "No endpoint created" unless orig = @sock.originate(target: 'sofia/external/%s@%s' % [vm_extension, @server2],
                  endpoint: "&transfer('4000 XML default')")
  # Store the response
  @resp = orig.run(:api)

  # Now check if we at least got INTO the voicemail extension
  fail "Unable to connect to voicemail" unless valid_code_here
end

Then /^I should be connected to that extension$/ do
  message, @uuid = @resp["body"].split(" ")
  fail "No UUID found" unless message == '+OK'
end

When /^I dial unknown extension (\d+)$/ do | unknown_extension|
  orig = @sock.originate(target: 'sofia/external/%s@%s' % [unknown_extension, @server2],
                         endpoint: "&transfer('3000 XML default')")
  @resp = orig.run(:api)
  fail "Previous command did not generate an error" unless @resp["body"].match /^-ERR/
end

Then /^I should be notified the call failed$/ do
  status, @message = @resp["body"].split(" ")
  fail unless status == '-ERR'
end

Then /^I should recieve call failure type (\w+)$/ do |failure_type|
  fail unless @message == 'NO_USER_RESPONSE'
end

When /^I am prompted for my extension and password$/ do
  pending # express the regexp above with the code you wish you had
end

When /^I supply my extension and password$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be logged into voicemail$/ do
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
