require 'rubygems'
require 'ffi-rzmq'
Thread.abort_on_exception = true


# PUB and SUB sockts work together to broadcast messages out to many clients
# A single PUB socket can talk to multiple SUB sockets at the same time.
# Messages only go one way, from the PUB to the SUB.
# 
# SUB sockets can filter the messages they receive, checking the prefix of the message
# for an exact sequence of bytes, discarding messages that don't start with this prefix.
#
# One important thing to note about PUB sockets, is that when created with 'bind'
# that is when listening for incoming SUB connections, they don't queue messages unless
# there's a connected SUB socket, their messages are effectively black holed.
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
# Each socket will get its own thread, so you'll see them run simultanously

ctx = ZMQ::Context.new(1)

# This is our publisher
Thread.new do
  pub_sock = ctx.socket(ZMQ::PUB)
  pub_sock.bind('tcp://127.0.0.1:2200')
  
  # This time, our publisher will send out messages indefinitel
  loop do
    puts "P: Sending our first message, about the Time Machine"
    
    # ZeroMQ messages can be broken up into multiple parts.
    # Messages are guaranteed to either come with all parts or not at all,
    # so don't worry about only receiving a partial message.
    
    # We're going to send the topic in a separate part, it's what the SUB socket
    # will use to decide if it wants to receive this message.
    # You don't need to use two parts for a pub/sub socket, but if you're using
    # topics its a good idea as matching terminates after the first part.
    pub_sock.send_string('Important', ZMQ::SNDMORE)     #Topic
    pub_sock.send_string('Find Time Machine')           #Body

    puts "P: Sending our second message, about Brawndo"
    pub_sock.send_string('Unimportant', ZMQ::SNDMORE)   #Topic
    pub_sock.send_string('Drink Brawndo')               #Body

    #Lets wait a second between messages
    sleep 1
  end
end

# Our Subscribers
# We're going to create two subscribers, each running in a separate
# thread.
# Messages come in multiple parts, the first being a topic. 
sub_threads = []
2.times do |i|
  sub_threads <<  Thread.new do
    sub_sock = ctx.socket(ZMQ::SUB)
    sub_sock.setsockopt(ZMQ::SUBSCRIBE,'Important')
    sub_sock.connect('tcp://127.0.0.1:2200')
    
    5.times do
      # Since our messages are coming in multiple parts, we have to
      # check for that here
      topic    = sub_sock.recv_string
      body     = sub_sock.recv_string if sub_sock.more_parts?
      
      puts "S#{i}: I received a message! The topic was '#{topic}'"
      puts "S#{i}: The body of the message was '#{body}'"
    end
  end
end

sub_threads.each {|t| t.join}
ctx.terminate
