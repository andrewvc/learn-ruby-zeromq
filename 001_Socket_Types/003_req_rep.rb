require 'rubygems'
require 'ffi-rzmq'
Thread.abort_on_exception = true

# REQ and REP sockets work together to establish a synchronous bidirectional flow of data.
# You can think of REQ and REP much like you'd think of a protocol like HTTP, you send a request,
# and you get a response. In between the request and response the thread is blocked.
# 
# REQ sockets are load balanced among all clients, exactly like PUSH sockets. REP responses are
# correctly routed back to the originating REQ socket.
#
# To start, we're going to build a simple rep/req message system that looks like this:
#
#                          req_sock
#                             |
#                          rep_sock
#

ctx = ZMQ::Context.new(1)

#Lets set ourselves up for replies
Thread.new do
  rep_sock = ctx.socket(ZMQ::REP)
  rep_sock.bind('tcp://127.0.0.1:2200')
  
  begin
    while message = rep_sock.recv_string
      puts "Received request '#{message}'"
      # You must send a reply back to the REQ socket.
      # Otherwise the REQ socket will be unable to send any more requests
      rep_sock.send_string('Polo!')
    end
  rescue ZMQ::SocketError
  end
end

req_sock = ctx.socket(ZMQ::REQ)
req_sock.connect('tcp://127.0.0.1:2200')

2.times do
  req_sock.send_string('Marco...')
  rep = req_sock.recv_string
  puts "Received reply '#{rep}'"
end

ctx.terminate
