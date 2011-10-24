require 'rubygems'
require 'ffi-rzmq'
Thread.abort_on_exception = true

# TODO: This section could be clearer, perhaps NOBLOCK should be moved
# to its own lesson?

# PAIR sockets are perhaps the simplest ZMQ socket type.
# PAIR sockets can only talk to a single other PAIR socket, exchanging
# an stream of messages. PAIR sockets can be thought of in 
# somewhat similar terms to a TCP stream, but with messaging and queueing.
#
# It should be noted that PAIR sockets are experimental, and are missing
# some features, like auto-reconnection.
#
# We're also going to learn about non blocking methods in this
# tutorial. By using the ZMQ::NOBLOCK option when sending or receiving 
# a message, your calls don't wait for results, at the expense of 
# more complicated control flow and error handling.
#
# We're going to build a simple PAIR connection that looks like:
#
#                            pair_sock1
#                                |
#                            pair_sock2
#

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

addr = 'tcp://127.0.0.1:2200'

threads = []
recv_counts = {:bind => 0, :connect => 0}

#One of our sockets will bind, the other will connect
[:bind, :connect].each do |conn_method|
  threads << Thread.new do
    sock = ctx.socket(ZMQ::PAIR)
    error_check(sock.setsockopt(ZMQ::LINGER, 1))
    
    if conn_method == :bind
      error_check(sock.bind(addr))
    else
      error_check(sock.connect(addr))
    end
    
    5.times do |i|
      # We're going to make the bind socket fast sending twice the
      # # of messages out as the connect socket.
      #
      # This means we'll see that the connect socket
      # receives about twice as many messages as the bind, which
      # you should see in the results.
      # 
      # Because the connect socket uses a nonblocking receive, it can
      # tell when there are no more messages to receive. A normal
      # receive would block, halting the thread till it received a
      # message.
      #
      # Later when we learn about polling, we'll see another approach
      # to this problem.
      conn_method == :bind ? sleep(1) : sleep(2)
     
      # Read messages off the queue until there are none, if there
      # are none let the loop continue
      msg = ''
      rc = 0
      while ZMQ::Util.resultcode_ok?(rc)
        break if error_check(sock.recv_string(msg, ZMQ::NOBLOCK))
        puts "#{conn_method} socket received #{msg}"
      end
      puts "#{conn_method} socket looping, nothing more to receive"

      # We're setting the NOBLOCK option here, even though this call
      # wouldn't block anyway. NOBLOCK on sends makes sense when you
      # Note that even the blocking send doesn't guarantee that your
      # message has been transmitted, just that it has been queued.
      #
      # One use for non-blocking sends would be in a socket type that can
      # queue messages, but normally blocks without being connected to
      # another similar socket, say a REQ/REP pair
      break if error_check(sock.send_string("##{i} FROM #{conn_method} socket", ZMQ::NOBLOCK))
    end
    
    # always close a socket when we're done with it otherwise
    # the context termination will hang indefinitely
    error_check(sock.close)
    puts "Closed socket; terminating thread..."
  end
end

threads.each {|t| t.join}

puts "Statistics: ", recv_counts.inspect

ctx.terminate
puts "Successfully terminated context; exiting..."


# A successful run looks like:

#$ ruby 005_pair.rb 
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#bind socket looping, nothing more to receive
#connect socket received #0 FROM bind socket
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#connect socket looping, nothing more to receive
#bind socket received #0 FROM connect socket
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#bind socket looping, nothing more to receive
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#bind socket looping, nothing more to receive
#connect socket received #1 FROM bind socket
#connect socket received #2 FROM bind socket
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#connect socket looping, nothing more to receive
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#bind socket looping, nothing more to receive
#bind socket received #1 FROM connect socket
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#bind socket looping, nothing more to receive
#Closed socket; terminating thread...
#connect socket received #3 FROM bind socket
#connect socket received #4 FROM bind socket
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#connect socket looping, nothing more to receive
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#connect socket looping, nothing more to receive
#Operation failed, errno [35] description [Resource temporarily unavailable]
#005_pair.rb:79:in `__script__'
#005_pair.rb:57:in `__script__'
#connect socket looping, nothing more to receive
#Closed socket; terminating thread...
#Statistics: 
#{:bind=>0, :connect=>0}
#Successfully terminated context; exiting...
