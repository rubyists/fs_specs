require "fsr"
require "fsr/listener/inbound"
require "fsr/command_socket"
FSR.load_all_commands
class IvrListener < FSL::Inbound
  # Commented out PLAYBACK_FILES because its already defined higher
  PLAYBACK_FILES = []
  SOUNDS = {
    vm_enter_id: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_id.wav",
    vm_enter_pass: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-enter_pass.wav",
    pound: "file_string://ascii/35.wav",
    vm_abort: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-abort.wav",
    vm_goodbye: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-goodbye.wav",
    vm_press: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-press.wav",
    vm_no_messages: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-no_messages.wav",
    vm_fail: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-fail_auth.wav",
    vm_has_messages: "/var/lib/freeswitch/sounds/en/us/callie/voicemail/vm-you_have.wav",
  }
  def initialize(sock1, sock2, server1, server2, username, password)
    @sock1, @sock2, @server1, @server2 = sock1, sock2, server1, server2, username, password
    @vm_extension = "%s#" % username
    @vm_password = "%s#" % password
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

  def enter_extension
    @sock1.uuid_send_dtmf(uuid: @uuid, dtmf: @vm_extension).run
  end

  def enter_password
    @sock1.uuid_send_dtmf(uuid: @uuid, dtmf: @vm_password).run
  end

  def handle_event(event)
    #p event.content[:caller_caller_id_number]
    return unless (event.content[:caller_caller_id_number] == @spec_id)
    path = event.content[:playback_file_path]
    if(path == SOUNDS[:pound] and PLAYBACK_FILES.last == SOUNDS[:vm_enter_id])
      enter_extension
    end
    if(path == SOUNDS[:pound] and PLAYBACK_FILES.last == SOUNDS[:vm_enter_pass])
      enter_password
    end
    # We call it logged in (or unsuccessful) when we hear any of these wavs
    if(path == SOUNDS[:vm_no_messages] || path == SOUNDS[:vm_has_messages] || path == SOUNDS[:vm_fail])
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
