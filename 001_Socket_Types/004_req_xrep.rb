require 'rubygems'
require 'ffi-rzmq'
Thread.abort_on_exception = true

# XREP sockets let a single XREP socket connect to many connecting REQ sockets.
# XREP accomplish this by tracking each connecting REQ socket's identity.
# Think of it as a multiplexed REP socket.
#
# XREP sockets receive messages in at least 3 message parts:
# The first part is the identity of the REQ socket connecting to it.
# The second part is an empty message, known as the delimiter
# Subsequent parts are the actual body of the message.
#
# The first two parts don't need to be sent manually by the connecting REQ socket
# The XREP socket adds them in itself
#
# In this example we're going to build a simple REQ / XREP echo server
 
ctx = ZMQ::Context.new(1)

# Lets set ourselves up for replies
Thread.new do
  xrep_sock = ctx.socket(ZMQ::XREP)
  xrep_sock.bind('tcp://127.0.0.1:2200')
  
  begin
    loop do
      identity  = xrep_sock.recv_string
      delimiter = xrep_sock.recv_string
      body      = xrep_sock.recv_string
      
      xrep_sock.send_string(identity,  ZMQ::SNDMORE)
      xrep_sock.send_string(delimiter, ZMQ::SNDMORE)
      xrep_sock.send_string(body)
    end
  rescue ZMQ::SocketError
  end
end

# Let's send some requests, concurrently
req_threads = []
2.times do |requester_id|
  req_threads << Thread.new do
    req_sock = ctx.socket(ZMQ::REQ)
    req_sock.connect('tcp://127.0.0.1:2200')
    
    10.times do
      req_sock.send_string("#{requester_id} says Marco...")
      rep = req_sock.recv_string
      puts "#{requester_id} Received reply '#{rep}'"
      
      sleep 0.2
    end
  end
end

req_threads.each {|t| t.join}

sleep 1 #This fixes mysterious errors
ctx.terminate
