And /^I can make a phone call$/ do
  # TODO: remove duplication
  orig = @sock.originate(target: "sofia/external/3000@#{@server2}:5080", endpoint: '&transfer(3000)')
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
  @sock.calls.run.detect { |call| call.uuid == uuid }.size.should == 1
  @conf_uuid = uuid
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

