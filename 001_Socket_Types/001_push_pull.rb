require 'rubygems'
require 'ffi-rzmq'
Thread.abort_on_exception = true

# PUSH and PULL sockets work together to load balance messages going one way.
# Multiple PULL sockets connected to a PUSH each receive messages from the PUSH.
# ZeroMQ automatically load balances the messages between all pull sockets.
#
# We're going to build a simple load balanced message system that looks like this:
#
#                         push_sock
#                         /       \
#                  pull_sock1   pull_sock2
#
# Each socket will get its own thread, so you'll see them run simultanously

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

#The context creates all ZeroMQ sockets.
#It's thread safe, and multiple contexts can exist within an application.
ctx = ZMQ::Context.create(1)

STDERR.puts "Failed to create a Context" unless ctx

push_thread = Thread.new do
  #Here we're creating our first socket. Sockets should not be shared among threads.
  push_sock = ctx.socket(ZMQ::PUSH)
  error_check(push_sock.setsockopt(ZMQ::LINGER, 0))
  rc = push_sock.bind('tcp://127.0.0.1:2200')
  error_check(rc)
  
  7.times do |i|
    msg = "#{i + 1} Potato"
    puts "Sending #{msg}"
    #This will block till a PULL socket connects`
    rc = push_sock.send_string(msg)
    break if error_check(rc)
    
    #Lets wait a second between messages
    sleep 1
  end
  
  # always close a socket when we're done with it otherwise
  # the context termination will hang indefinitely
  error_check(push_sock.close)
end

#Here we create two pull sockets, you'll see an alternating pattern
#of message reception between these two sockets
pull_threads = []
2.times do |i|
  pull_threads << Thread.new do
    pull_sock = ctx.socket(ZMQ::PULL)
    error_check(pull_sock.setsockopt(ZMQ::LINGER, 0))
    sleep 3
    puts "Pull #{i} connecting"
    rc = pull_sock.connect('tcp://127.0.0.1:2200')
    error_check(rc)
    
    #Here we receive message strings; allocate a string to receive
    # the message into
    message = ''
    rc = 0
    #On termination sockets raise an error where a call to #recv_string will
    # return an error, lets handle this nicely
    #Later, we'll learn how to use polling to handle this type of situation
    #more gracefully
    while ZMQ::Util.resultcode_ok?(rc)
      rc = pull_sock.recv_string(message)
      puts "Pull#{i}: I received a message '#{message}'"
    end
    
    # always close a socket when we're done with it otherwise
    # the context termination will hang indefinitely
    error_check(pull_sock.close)
    puts "Socket closed; thread terminating"
  end
end

#Wait till we're done pushing messages
push_thread.join
puts "Done pushing messages"

#Terminate the context to close all sockets
ctx.terminate
puts "Terminated context"

#Wait till the pull threads finish executing
pull_threads.each {|t| t.join}

puts "Done!"


# A successful run looks like:

#$ ruby 001_push_pull.rb 
#Sending 1 Potato
#Pull 0 connectingPull 1 connecting
#
#Pull0: I received a message '1 Potato'
#Sending 2 Potato
#Pull0: I received a message '2 Potato'
#Sending 3 Potato
#Pull1: I received a message '3 Potato'
#Sending 4 Potato
#Pull0: I received a message '4 Potato'
#Sending 5 Potato
#Pull1: I received a message '5 Potato'
#Sending 6 Potato
#Pull0: I received a message '6 Potato'
#Sending 7 Potato
#Pull1: I received a message '7 Potato'
#Done pushing messages
#Pull1: I received a message '7 Potato'
#Socket closed; thread terminating
#Pull0: I received a message '6 Potato'
#Socket closed; thread terminating
#Terminated context
#Done!
