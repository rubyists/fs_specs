Then /^I should be able to build a prototype$/ do
  EM.run do
    #  Wait 60 seconds
    EM.add_periodic_timer(60) { |e| EM.stop }
  end
end
