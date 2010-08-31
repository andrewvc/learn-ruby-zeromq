# NOTE: This example isn't quite ready for students,
# It's not styled right, and is just here for me to 
# rough out an idea for this lesson.
# Annotations and explanations will come in good time

require 'rubygems'
require 'zmqmachine'
Thread.abort_on_exception = true

ADDR = ZM::Address.new('127.0.0.1', 2200, :tcp)

class PubHandler
  def initialize(reactor,name)
    @reactor  = reactor
    @name = name
    @sent_messages = 0
    @write_queue   = []
  end
  
  def on_attach(socket)
    @socket = socket
    socket.bind(ADDR)
  end

  def on_writable(socket)
    unless @write_queue.empty?
      message = @write_queue.shift
      socket.send_message_string message
    else
      # when the messages are sent, deregister for write events to disable
      # the "busy" loop
      @reactor.deregister_writable(socket)
    end
  end

  def queue_writable_message(message)
    @write_queue << message
    @reactor.register_writable(@socket)
  end
end

class SubHandler
  def initialize(reactor,name)
    @reactor  = reactor
    @name = name
  end
  
  def on_attach(socket)
    socket.connect(ADDR)
    socket.subscribe('')
  end
   
  def on_readable(socket,messages)
    message = messages.first.copy_out_string
    puts "#{@name}: #{message}"
  end
end

reactor = ZM::Reactor.new(:my_reactor).run do |reactor|
  pub_handler = PubHandler.new(reactor, 'pub1')
  reactor.pub_socket(pub_handler)
  count = 0
  reactor.periodical_timer(500) do #Timer delay is in MS
    count += 1
    pub_handler.queue_writable_message("Message #{count}")
  end 

  reactor.sub_socket(SubHandler.new(reactor, 'sub1'))
  reactor.sub_socket(SubHandler.new(reactor, 'sub2'))
end

Thread.new { sleep 5; reactor.stop }
reactor.join
