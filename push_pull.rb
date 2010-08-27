require 'rubygems'
require 'ffi-rzmq'

#PUSH and PULL sockets work together to load balance messages going one way.
#Multiple PULL sockets connected to a PUSH each receive messages from the PUSH.
#ZeroMQ automatically load balances the messages between all pull sockets.
push_thread = Thread.new do
  push_ctx = ZMQ::Context.new(1) 
  push_sock = push_ctx.socket(ZMQ::PUSH)
  push_sock.bind('tcp://127.0.0.1:2200')
  
  10.times do |i|
    puts "Sending #{msg}"
    msg = "#{i + 1} Potato"
    push_sock.send_string(msg)

    #Lets wait a second between messages
    sleep 1
  end
end

#Here we create two pull sockets, you'll see an alternating pattern
#of message reception between these two sockets
2.times do |i|
  Thread.new do
    pull_ctx  = ZMQ::Context.new(1)   
    pull_sock = pull_ctx.socket(ZMQ::PULL)
    pull_sock.connect('tcp://127.0.0.1:2200')
    
    10.times do
      message = pull_sock.recv_string
      puts "S#{i}: I received a message '#{message}'"
    end
  end
end

push_thread.join
