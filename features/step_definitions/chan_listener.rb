require "fsr"
require "fsr/listener/inbound"
require "fsr/command_socket"
FSR.load_all_commands
class ChanListener < FSL::Inbound
  # Commented out PLAYBACK_FILES because its already defined higher
  CHAN_STATE= {}

  def initialize(sock1, sock2, server1, server2, known_extension)
    @sock1, @sock2, @server1, @server2 = sock1, sock2, server1, server2
    @number_to_call = known_extension # This is populated from Step, passed in When I dial extension "9192"
    super()
  end

  def before_session
    # subscribe to events
    add_event(:ALL){|event| handle_event(event) }
  end

  def post_init
    @spec_id = rand(100000000).to_s
    orig = @sock1.originate(target_options: {origination_caller_id_number: @spec_id}, target: "sofia/external/#{@number_to_call}@#{@server2}", endpoint: '&park')
    @uuid = orig.run(:api)['body'].split[1]
    warn "UUID is #{@uuid}"
    warn "spec_id is #{@spec_id}"
  end

  def handle_event(event)
    #p event.content[:caller_caller_id_number]
    return unless (event.content[:caller_caller_id_number] == @spec_id)
    puts "EVENT DATA - contents of event"
    puts "event.content class = #{event.content.class} (contents displayed after headers)"
    puts "event.headers class = #{event.headers.class}"
    puts "event.headers content = #{event.headers}"
    puts "event.headers.keys = #{event.headers.keys}"
    puts
    puts "CHANNEL DATA - (For this specific event) - contents of event.content hash\n"
    printf("event.content.keys = #{event.content.keys.to_s}")
    puts
    # We call it logged in (or unsuccessful) when we hear any of these wavs
    #if(path == @expected_sound)
      # And hang up the call
      @sock1.kill(@uuid).run
      # Then stop the reactor
      EM.stop
    #end

  end

  def unbind
  end
end

if __FILE__ == $0
  @server1 = 'blackbird.rubyists.com'
  @server2 = 'tigershark.rubyists.com'
  @sock1 = FSR::CommandSocket.new(server: @server1)
  @sock2 = FSR::CommandSocket.new(server: @server2)
  warn "Starting ChanListener, someone better check the IVR quick!"
  EM.run do
    EM.add_periodic_timer(20) { |e| EM.stop }
    # When I press 5, I expect 'screaming monkeys' or what-not
    EM.connect(@server2, 8021, ChanListener, @sock1, @sock2, @server1, @server2, "4", ChanListener::SOUNDS[:ivr_cluecon])
  end
  p ChanListener::PLAYBACK_FILES
end
