When /^I make a phone call$/ do
  orig = @sock.originate(target: "sofia/external/3000@#{@server2}:5080", endpoint: '&transfer(9664)')
  uuid = orig.run(:api)['body'].split[1]

  # Due to asyncronous nature of the entire method chain
  # which involves network stack, call plans, etc..
  # We sleep long enough for the call creations have been handled _throughout_ the stack.
  # We limit our sleep times to < 1s in order to wait the last amount of time,
  # and include additional checks oside the sleep to limit wait time further.
  30.times do
    sleep 0.1
    break if @sock.calls.run.any?{|call| call.uuid == uuid }
  end
  @sock.calls.run.size.should == 1
end

Given /^I have 2 servers named ([\w.]+) and ([\w.]+)$/ do |server1, server2|
  @server1, @server2 = server1, server2
  @sock = FSR::CommandSocket.new(server: @server1, port: 8021)
end

Then /^I should be able to terminate the call$/ do
  @sock.calls.run.each do |call|
    @sock.say("api uuid_kill #{call.uuid}")
  end

  # Due to asynchronous nature of the entire method chain
  # which involves network stack, call plans, etc..
  # We wait until all call deletions have caught up to us.
  30.times do
    sleep 0.1
    break if @sock.calls.run.empty?
  end
  @sock.calls.run.size.should == 0
end

Given /^I have registered to FreeSWITCH$/ do
  steps %{
    When I make a phone call
  }
end

Given /^I have a conference object$/ do
  confs = @sock.conference(:list).run
  p confs
  #pending # express the regexp above with the code you wish you had
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

When /^I dial registered extension "([^"]*)"$/ do |regged_extension|
  pending # express the regexp above with the code you wish you had
end

Then /^I should be connected to that extension$/ do
  pending # express the regexp above with the code you wish you had
end

When /^I dial unregistered extension "([^"]*)"$/ do | unregged_extension|
  pending # express the regexp above with the code you wish you had
end

Then /^I should be notified the call failed$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should recieve call failure type (\w+)$/ do |failure_type|
  pending # express the regexp above with the code you wish you had
end

