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
# You may be wondering why an empty delimiter message is needed, 
# the answer is forwarding. While we won't cover it in this introductory
# example, messages can have multiple identiy message parts if the messages
# are passed through a chain of ZeroMQ XREQ/XREP sockets.
# See http://zeromq.wikidot.com/recipe:new-recipe for an example.
#
# The first two parts don't need to be sent manually by the connecting REQ socket
# The XREP socket adds them in itself
#
# In this example we're going to build a simple REQ / XREP echo server

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end
 
ctx = ZMQ::Context.new(1)

# Lets set ourselves up for replies
Thread.new do
  xrep_sock = ctx.socket(ZMQ::XREP)
  error_check(xrep_sock.bind('tcp://127.0.0.1:2200'))
  
  identity, delimiter, body = '', '', ''
    
  loop do
    break if error_check(xrep_sock.recv_string(identity))
    break if error_check(xrep_sock.recv_string(delimiter))
    break if error_check(xrep_sock.recv_string(body))
      
    break if error_check(xrep_sock.send_string(identity,  ZMQ::SNDMORE))
    break if error_check(xrep_sock.send_string(delimiter, ZMQ::SNDMORE))
    break if error_check(xrep_sock.send_string(body))
  end

  # always close a socket when we're done with it otherwise
  # the context termination will hang indefinitely
  error_check(xrep_sock.close)
end

# Let's send some requests, concurrently
req_threads = []
2.times do |requester_id|
  req_threads << Thread.new do
    req_sock = ctx.socket(ZMQ::REQ)
    error_check(req_sock.connect('tcp://127.0.0.1:2200'))
    
    rep = ''
    10.times do
      break if error_check(req_sock.send_string("#{requester_id} says Marco..."))
      break if error_check(req_sock.recv_string(rep))
      puts "#{requester_id} Received reply '#{rep}'"
      
      sleep 0.2
    end
    
    error_check(req_sock.close)
  end
end

req_threads.each {|t| t.join}

sleep 1 #This fixes mysterious errors
ctx.terminate
puts "Successfully terminated context; exiting..."

# A successful run looks like:

#$ ruby 004_req_xrep.rb 
#0 Received reply '0 says Marco...'
#1 Received reply '1 says Marco...'
#0 Received reply '0 says Marco...'
#1 Received reply '1 says Marco...'
#0 Received reply '0 says Marco...'1 Received reply '1 says Marco...'
#
#1 Received reply '1 says Marco...'0 Received reply '0 says Marco...'
#
#0 Received reply '0 says Marco...'
#1 Received reply '1 says Marco...'
#0 Received reply '0 says Marco...'
#1 Received reply '1 says Marco...'
#1 Received reply '1 says Marco...'
#0 Received reply '0 says Marco...'
#1 Received reply '1 says Marco...'
#0 Received reply '0 says Marco...'
#1 Received reply '1 says Marco...'
#0 Received reply '0 says Marco...'
#1 Received reply '1 says Marco...'
#0 Received reply '0 says Marco...'
#Operation failed, errno [156384765] description [Context was terminated]
#004_req_xrep.rb:45:in `__script__'
#004_req_xrep.rb:44:in `__script__'
#Successfully terminated context; exiting...
