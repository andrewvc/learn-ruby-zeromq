require 'rubygems'
require 'ffi-rzmq'
Thread.abort_on_exception = true


# PUB and SUB sockets work together to broadcast messages out to many clients.
# A single PUB socket can talk to multiple SUB sockets at the same time.
# Messages only go one way, from the PUB to the SUB.
# 
# SUB sockets can filter the messages they receive, checking the prefix of the message
# for an exact sequence of bytes, discarding messages that don't start with this prefix.
#
# One important thing to note about PUB sockets, is that when created with 'bind'
# they are listening for incoming SUB connections. They won't queue messages unless
# there's a connected SUB socket, and their messages are effectively black holed.
#
# So, don't plan on all PUB messages making their way anywhere unless there's a connected
# SUB socket. When created with 'connect' (which is perhaps atypical for a pub/sub topology),
# queing of messages does takes place.
#
# We're also going to learn about multipart messages in this example
#
# We're going to build a simple pub/sub message system that looks like this:
#
#                          pub_sock
#                         /       \
#                  sub_sock1     sub_sock2
#
# Each socket will get its own thread, so you'll see them run simultanously.

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

ctx = ZMQ::Context.create(1)
STDERR.puts "Failed to create a Context" unless ctx

# This is our publisher
Thread.new do
  pub_sock = ctx.socket(ZMQ::PUB)
  error_check(pub_sock.setsockopt(ZMQ::LINGER, 1))
  rc = pub_sock.bind('tcp://127.0.0.1:2200')
  error_check(rc)
  
  # This time, our publisher will send out messages indefinitely
  loop do
    puts "P: Sending our first message, about the Time Machine"
    
    # ZeroMQ messages can be broken up into multiple parts.
    # Messages are guaranteed to either come with all parts or not at all,
    # so don't worry about only receiving a partial message.
    
    # We're going to send the topic in a separate part, it's what the SUB socket
    # will use to decide if it wants to receive this message.
    # You don't need to use two parts for a pub/sub socket, but if you're using
    # topics its a good idea as matching terminates after the first part.
    rc = pub_sock.send_string('Important', ZMQ::SNDMORE)     #Topic
    break if error_check(rc)
    rc = pub_sock.send_string('Find Time Machine')           #Body
    break if error_check(rc)

    puts "P: Sending our second message, about Brawndo"
    rc = pub_sock.send_string('Unimportant', ZMQ::SNDMORE)   #Topic
    break if error_check(rc)
    rc = pub_sock.send_string('Drink Brawndo')               #Body
    break if error_check(rc)

    #Lets wait a second between messages
    sleep 1
  end
  
  # always close a socket when we're done with it otherwise
  # the context termination will hang indefinitely
  error_check(pub_sock.close)
  puts "Pub thread is exiting..."
end

# Our Subscribers
# We're going to create two subscribers, each running in a separate
# thread.
# Messages come in multiple parts, the first being a topic. 
sub_threads = []
2.times do |i|
  sub_threads <<  Thread.new do
    sub_sock = ctx.socket(ZMQ::SUB)
    error_check(sub_sock.setsockopt(ZMQ::LINGER, 1))
    rc = sub_sock.setsockopt(ZMQ::SUBSCRIBE,'Important')
    error_check(rc)
    rc = sub_sock.connect('tcp://127.0.0.1:2200')
    error_check(rc)
    
    5.times do
      # Since our messages are coming in multiple parts, we have to
      # check for that here
      topic = ''
      rc = sub_sock.recv_string(topic)
      break if error_check(rc)
      body = ''
      rc = sub_sock.recv_string(body) if sub_sock.more_parts?
      break if error_check(rc)
      
      puts "S#{i}: I received a message! The topic was '#{topic}'"
      puts "S#{i}: The body of the message was '#{body}'"
    end
    
    # always close a socket when we're done with it otherwise
    # the context termination will hang indefinitely
    error_check(sub_sock.close)
    puts "Thread [#{i}] is exiting..."
  end
end

sub_threads.each {|t| t.join}
puts "Sub threads have terminated; terminating context"

ctx.terminate
puts "terminated"

# A successful run looks like:

#$ ruby 002_publish_subscribe.rb 
#P: Sending our first message, about the Time Machine
#P: Sending our second message, about Brawndo
#P: Sending our first message, about the Time Machine
#P: Sending our second message, about Brawndo
#S1: I received a message! The topic was 'Important'
#S0: I received a message! The topic was 'Important'S1: The body of the message was 'Find Time Machine'
#
#S0: The body of the message was 'Find Time Machine'
#P: Sending our first message, about the Time Machine
#P: Sending our second message, about Brawndo
#S1: I received a message! The topic was 'Important'
#S1: The body of the message was 'Find Time Machine'
#S0: I received a message! The topic was 'Important'
#S0: The body of the message was 'Find Time Machine'
#P: Sending our first message, about the Time Machine
#P: Sending our second message, about Brawndo
#S1: I received a message! The topic was 'Important'
#S1: The body of the message was 'Find Time Machine'
#S0: I received a message! The topic was 'Important'
#S0: The body of the message was 'Find Time Machine'
#P: Sending our first message, about the Time Machine
#P: Sending our second message, about Brawndo
#S1: I received a message! The topic was 'Important'
#S1: The body of the message was 'Find Time Machine'
#S0: I received a message! The topic was 'Important'
#S0: The body of the message was 'Find Time Machine'
#P: Sending our first message, about the Time Machine
#P: Sending our second message, about Brawndo
#S0: I received a message! The topic was 'Important'
#S0: The body of the message was 'Find Time Machine'
#S1: I received a message! The topic was 'Important'
#S1: The body of the message was 'Find Time Machine'
#Thread [1] is exiting...Thread [0] is exiting...
#
#Sub threads have terminated; terminating context
#P: Sending our first message, about the Time Machine
#Operation failed, errno [156384765] description [Context was terminated]
#002_publish_subscribe.rb:64:in `__script__'
#002_publish_subscribe.rb:52:in `__script__'
#Pub thread is exiting...
#terminated
