require 'rubygems'
require 'ffi-rzmq'

#Our publisher, everything our publisher says gets broadcast to
#connected Subscribers
Thread.new do
  pub_ctx = ZMQ::Context.new(1)   #Create a new ZeroMQ Context
  pub_sock = pub_ctx.socket(ZMQ::PUB)
  pub_sock.bind('tcp://127.0.0.1:2200')
  loop do
    puts "P: Sending our first message, about the Time Machine"
    pub_sock.send_string('Important', ZMQ::SNDMORE)         #Topic
    pub_sock.send_string('Find Time Machine',ZMQ::SNDMORE)  #Body
    pub_sock.send_string(pub_sock.identity)                 #Terminate

    puts "P: Sending our second message, about Brawndo"
    pub_sock.send_string('Unimportant', ZMQ::SNDMORE)   #Topic
    pub_sock.send_string('Drink Brawndo', ZMQ::SNDMORE) #Body
    pub_sock.send_string(pub_sock.identity)             #Terminate

    #Lets wait a second between messages
    sleep 1
  end
end

#Our Subscribers
#We're going to create two subscribers, each running in a separate
#thread.
#Messages come in multiple parts, the first being a topic. 
#Create a new ZeroMQ Context. You must, create one per thread.
threads = []
2.times do |i|
  threads <<  Thread.new do
    sub_ctx = ZMQ::Context.new(1)   
    sub_sock = sub_ctx.socket(ZMQ::SUB)
    sub_sock.setsockopt(ZMQ::SUBSCRIBE,'Important')
    sub_sock.connect('tcp://127.0.0.1:2200')
    
    10.times do
      topic    = sub_sock.recv_string
      body     = sub_sock.recv_string if sub_sock.more_parts?
      identity = sub_sock.recv_string if sub_sock.more_parts?
      
      puts "S#{i}: I received a message! The topic was '#{topic}'"
      puts "S#{i}: The body of the message was '#{body}'"
    end
  end
end

#Wait until the threads are done to terminate
threads.each {|t| t.join}
