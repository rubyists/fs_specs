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
    ivr_cluecon: "/var/lib/freeswitch/sounds/en/us/callie/ivr/8000/ivr-register_for_cluecon.wav",
    ivr_please: "/var/lib/freeswitch/sounds/en/us/callie/ivr/ivr-please.wav",
    ivr_press: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
    ivr_digit: "/var/lib/freeswitch/sounds/en/us/callie/digits/%s.wav"
  }
  def initialize(sock1, sock2, server1, server2, key_sequence, expected_sound, number_to_call = '5000', welcome_sound = SOUNDS[:ivr_welcome])
    @sock1, @sock2, @server1, @server2 = sock1, sock2, server1, server2
    @key_sequence = "%s#" % key_sequence
    @ivr_sound = SOUNDS[:ivr_digit] % key_sequence # that happens right there then what are you talking about i haven't makde that yet. make it right the eff now
    @expected_sound = expected_sound
    @number_to_call = number_to_call
    @welcome_sound = welcome_sound
    super()
  end

  def before_session
    # subscribe to events
    add_event(:PLAYBACK_STOP){|event| handle_event(event) }
  end

  def post_init
    @spec_id = rand(100000000).to_s
    orig = @sock1.originate(target_options: {origination_caller_id_number: @spec_id}, target: "sofia/external/#{@number_to_call}@#{@server2}", endpoint: '&park')
    @uuid = orig.run(:api)['body'].split[1]
    warn "UUID is #{@uuid}"
    warn "spec_id is #{@spec_id}"
  end

  def enter_key_sequence
    keystroke = @sock1.uuid_send_dtmf(uuid: @uuid, dtmf: @key_sequence)
    p keystroke.raw
    keystroke.run
  end

  def handle_event(event)
    #p event.content[:caller_caller_id_number]
    return unless (event.content[:caller_caller_id_number] == @spec_id)
    path = event.content[:playback_file_path]
    if(path == SOUNDS[:ivr_welcome])
      enter_key_sequence
    end
    # We call it logged in (or unsuccessful) when we hear any of these wavs
    if(path == @expected_sound)
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
    # When I press 5, I expect 'screaming monkeys' or what-not
    EM.connect(@server2, 8021, IvrListener, @sock1, @sock2, @server1, @server2, "4", IvrListener::SOUNDS[:ivr_cluecon])
  end
  p IvrListener::PLAYBACK_FILES
end
