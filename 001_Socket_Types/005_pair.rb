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

ctx = ZMQ::Context.new(1)

addr = 'tcp://127.0.0.1:2200'

threads = []
recv_counts = {:bind => 0, :connect => 0}

#One of our sockets will bind, the other will connect
[:bind, :connect].each do |conn_method|
  threads << Thread.new do
    sock = ctx.socket(ZMQ::PAIR)
    
    if conn_method == :bind
      sock.bind(addr)
    else
      sock.connect(addr)
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
      while msg = sock.recv_string(ZMQ::NOBLOCK)
        recv_counts[conn_method] += 1
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
      sock.send_string("##{i} FROM #{conn_method} socket", ZMQ::NOBLOCK)
    end
  end
end

threads.each {|t| t.join}

puts "Statistics: ", recv_counts.inspect

# Allow some cleanup time, preventing ruby 1.9.2 from not terminating
# jruby doesn't need this
sleep 1 
ctx.terminate
