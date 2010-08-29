# NOTE: This example isn't quite ready for students,
# It's not styled right, and is just here for me to 
# rough out an idea for this lesson.
# Annotations and explanations will come in good time

require 'rubygems'
require 'zmqmachine'
Thread.abort_on_exception = true

ADDR = ZM::Address.new('127.0.0.1', 2200, :tcp)

class PubHandler
  def initialize(ctx,name)
    @ctx  = ctx
    @name = name
    @sent_messages = 0
  end
  
  def on_attach(socket)
    socket.bind(ADDR)
  end

  def on_writable(socket)
    @sent_messages += 1
    msg = "#{@name} | #{@sent_messages}"
    puts "P: #{msg}"
    socket.send_message_string(msg)
    sleep 1
  end
end

class SubHandler
  def initialize(ctx,name)
    @ctx  = ctx
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

reactor = ZM::Reactor.new(:my_reactor).run do |ctx|
  ctx.pub_socket(PubHandler.new(ctx, 'pub1'))
   
  ctx.sub_socket(SubHandler.new(ctx, 'sub1'))
  ctx.sub_socket(SubHandler.new(ctx, 'sub2'))
end

reactor.join
