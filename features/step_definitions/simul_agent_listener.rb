require "fsr"
require "fsr/listener/inbound"
require "fsr/command_socket"
FSR.load_all_commands
class SimulAgentListener < FSL::Inbound
  # Use this for tracking channel state (like :channel_state and :channel_call_state)
  # These are all the currently documented __channel__ states for freeswitch.
  CHANNEL_STATE = {
    CS_NEW: "CS_NEW",
    CS_INIT: "CS_INIT",
    CS_ROUTING: "CS_ROUTING",
    CS_SOFT_EXECUTE: "CS_SOFT_EXECUTE",
    CS_EXECUTE: "CS_EXECUTE",
    CS_EXCHANGE_MEDIA: "CS_EXCHANGE_MEDIA",
    CS_PARK: "CS_PARK",
    CS_CONSUME_MEDIA: "CS_CONSUME_MEDIA",
    CS_HIBERNATE: "CS_HIBERNATE",
    CS_RESET: "CS_RESET",
    CS_HANGUP: "CS_HANGUP",
    CS_REPORTING: "CS_REPORTING",
    CS_DESTROY: "CS_DESTROY"
  }
  
  # These WANTED_STATE should eventually be populated externally from a step so that you can further refine granularity at the step level.
  # I just hardcoded for purposes of working with the class directly. This is where you would hunt on __call_state__ coupled with call-specific
  # variable contents.
  WANTED_STATE ={
  event_name: "CHANNEL_EXECUTE",
  channel_state: "CS_EXECUTE",
  call_state: "ACTIVE"
  }


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
    # Make sure we *only* process this specific spec's events
    return unless (event.content[:caller_caller_id_number] == @spec_id)
    #EM.add_periodic_timer(5) do
      return "NOT a json'd event!" unless (event.headers[:content_type] == "text/event-json")

      # This is what we really want to see
      if WANTED_STATE[:event_name] == "#{event.content[:event_name]}" && WANTED_STATE[:channel_state] == "#{event.content[:channel_state]}" && WANTED_STATE[:call_state] == "#{event.content[:channel_call_state]}"

        # Got what we wanted, so do your 'something'
        puts "Event we're handing is: #{event.content[:event_name]}"
        puts "GOT CHANNEL STATE - #{WANTED_STATE[:channel_state]}"
        puts "GOT CALL STATE == #{WANTED_STATE[:call_state]}"
        puts "WANTED_STATE triggered this. We can do fill_in_blank using just these:"
        puts "Caller #{event.content[:caller_channel_name]} dialed extension #{event.content[:caller_destination_number]} in the #{event.content[:caller_dialplan]} dialplan on #{event.content[:freeswitch_switchname]}."
        puts
        puts "event.content[:event_name] == #{event.content[:event_name]} | spec_id == #{@spec_id}"
        puts "event.content[:unique_id] == #{event.content[:unique_id]}"
        puts "event.content[:event_calling_file] == #{event.content[:event_calling_file]} | spec_id == #{@spec_id}"
        puts "event.content[:event_calling_function] == #{event.content[:event_calling_function]} | spec_id == #{@spec_id}"
        puts "event.content[:channel_name] == #{event.content[:channel_name]}"
        puts "event.content[:channel_state] == #{event.content[:channel_state]} | spec_id == #{@spec_id}"
        puts "event.content[:channel_call_state] == #{event.content[:channel_call_state]} | spec_id == #{@spec_id}"
        puts "event.content[:channel_hit_dialplan] == #{event.content[:channel_hit_dialplan]} | spec_id == #{@spec_id}"
        puts "event.content[:caller_channel_name] == #{event.content[:caller_channel_name]} | spec_id == #{@spec_id}"
        puts "event.content[:caller_unique_id] == #{event.content[:caller_unique_id]} | spec_id == #{@spec_id}"
        puts "event.content[:caller_source] == #{event.content[:caller_source]}"
        puts "event.content[:caller_network_addr] == #{event.content[:caller_network_addr]} | spec_id == #{@spec_id}"
        puts "event.content[:caller_caller_id_number] == #{event.content[:caller_caller_id_number]} | spec_id == #{@spec_id}"
        puts "event.content[:caller_direction] == #{event.content[:caller_direction]} | spec_id == #{@spec_id}"
        puts "event.content[:caller_context] == #{event.content[:caller_context]} | spec_id == #{@spec_id}"
        puts "event.content[:caller_dialplan] == #{event.content[:caller_dialplan]} | spec_id == #{@spec_id}"
        puts "event.content[:caller_destination_number] == #{event.content[:caller_destination_number]} | spec_id == #{@spec_id}"
        puts "event.content[:variable_current_application] == #{event.content[:variable_current_application]}"
        puts "event.content[:variable_originate_disposition] == #{event.content[:variable_originate_disposition]}"
        puts "event.content[:variable_endpoint_disposition] == #{event.content[:variable_endpoint_disposition]}"
        puts "event.content[:freeswitch_switchname] == #{event.content[:freeswitch_switchname]} | spec_id == #{@spec_id}"
        puts "= ENDS WANTED_STATE ="
      else
        puts "Got different than WANTED_STATE. Processing different event than we thought. We got: "
        puts "event.content[:event_name] == #{event.content[:event_name]} - event.content[:channel_state] == #{event.content[:channel_state]}  - event.content[:channel_call_state] == #{event.content[:channel_call_state]}"
        puts "event.content[:variable_originate_disposition] == #{event.content[:variable_originate_disposition]}"
        puts "event.content[:variable_endpoint_disposition] == #{event.content[:variable_endpoint_disposition]}"
      end
    #end ## Belongs to commented EM.add_periodic_timer(5) do 
  end

  def unbind
  end
end

if __FILE__ == $0
  @server1 = 'blackbird.rubyists.com'
  @server2 = 'tigershark.rubyists.com'
  @sock1 = FSR::CommandSocket.new(server: @server1)
  @sock2 = FSR::CommandSocket.new(server: @server2)
  warn "Starting SimulAgentListener.. Mining socket.."
  EM.run do
    EM.add_periodic_timer(30) { |e| EM.stop }
    EM.connect(@server2, 8021, SimulAgentListener, @sock1, @sock2, @server1, @server2, "9192")
  end
end
