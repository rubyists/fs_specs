require "fsr"
require "fsr/listener/inbound"
require "fsr/command_socket"
FSR.load_all_commands
class IvrListener < FSL::Inbound
  # Commented out PLAYBACK_FILES because its already defined higher
  PLAYBACK_FILES = []
  SOUNDS = {
    ivr_welcome: "/var/lib/freeswitch/sounds/en/us/callie/ivr/ivr-welcome_to_freeswitch.wav",
    ivr_screaming_monkeys: "/var/lib/freeswitch/sounds/en/us/callie/ivr/ivr-to_hear_screaming_monkeys.wav",
    ivr_please: "/var/lib/freeswitch/sounds/en/us/callie/ivr/ivr-please.wav",
    ivr_press: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
    ivr_digit: "/var/lib/freeswitch/sounds/en/us/callie/digits/#{@ivr_digit}.wav"
  }
  def initialize(sock1, sock2, server1, server2, key_sequence)
    @sock1, @sock2, @server1, @server2 = sock1, sock2, server1, server2, key_sequence
    @ivr_digit = "%s#" % key_sequence
    super()
  end

  def before_session
    # subscribe to events
    add_event(:PLAYBACK_STOP){|event| handle_event(event) }
  end

  def post_init
    @spec_id = rand(100000000).to_s
    orig = @sock1.originate(target_options: {origination_caller_id_number: @spec_id}, target: "sofia/external/5000@#{@server2}", endpoint: '&park')
    @uuid = orig.run(:api)['body'].split[1]
    warn "UUID is #{@uuid}"
    warn "spec_id is #{@spec_id}"
  end

  def enter_key_sequence
    @sock1.uuid_send_dtmf(uuid: @uuid, dtmf: IvrListener::SOUNDS[:ivr_digit]).run
  end

  def enter_password
    @sock1.uuid_send_dtmf(uuid: @uuid, dtmf: @vm_password).run
  end

  def handle_event(event)
    #p event.content[:caller_caller_id_number]
    return unless (event.content[:caller_caller_id_number] == @spec_id)
    path = event.content[:playback_file_path]
    if(path == SOUNDS[:ivr_welcome])
      enter_key_sequence
    end
    # We call it logged in (or unsuccessful) when we hear any of these wavs
    if(path == SOUNDS[:ivr_welcome] || path == SOUNDS[:ivr_screaming_monkeys])
      # And hang up the call
      @sock1.kill(@uuid).run
      # Then stop the reactor
      EM.stop
    end

    PLAYBACK_FILES << path
  end

  def unbind
  end
end

if __FILE__ == $0
  @server1 = 'blackbird.rubyists.com'
  @server2 = 'tigershark.rubyists.com'
  @sock1 = FSR::CommandSocket.new(server: @server1)
  @sock2 = FSR::CommandSocket.new(server: @server2)
  warn "Starting IvrListener, someone better check the IVR quick!"
  EM.run do
    EM.add_periodic_timer(20) { |e| EM.stop }
    EM.connect(@server2, 8021, IvrListener, @sock1, @sock2, @server1, @server2, "1000", "1001")
  end
  #p IvrListener::PLAYBACK_FILES
end
