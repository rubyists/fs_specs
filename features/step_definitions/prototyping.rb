Then /^I should be able to build a prototype$/ do
  EM.run do
    # Wait 60 seconds
    EM.add_periodic_timer(30) { |e| EM.stop }
    EM.connect(@server2, 8021, SimulAgentListener, @sock1, @sock2, @server1, @server2, known_extension = "9192")
  end
end
