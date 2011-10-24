
# In this example we have full control on what is sent to who, there is little to no
# documentation on this and that's why I made this example
# We have a server with 2 "clients" speaking to it, each one will have a predefined
# identity allowing to speak to a particular peer


require 'rubygems'
require 'ffi-rzmq'
Thread.abort_on_exception = true

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

# create context
ctx = ZMQ::Context.new(1)

# our server
server = ctx.socket(ZMQ::XREP)
error_check(server.setsockopt(ZMQ::IDENTITY, "server"))
error_check(server.bind('tcp://127.0.0.1:7777'))


# we add the two clients, set their identity and connect them
# to the server
clients = [
    ctx.socket(ZMQ::XREQ),
    ctx.socket(ZMQ::XREQ)
  ]


error_check(clients[0].setsockopt(ZMQ::IDENTITY, "client1"))
error_check(clients[0].connect('tcp://127.0.0.1:7777'))

error_check(clients[1].setsockopt(ZMQ::IDENTITY, "client2"))
error_check(clients[1].connect('tcp://127.0.0.1:7777'))


# now we start the real stuff, create a poller to monitor
# all the sockets and register them all
# (in a real world use the server and clients would be separated
# but it does not affect our example so they are all in one
# process here)
poller = ZMQ::Poller.new
poller.register_readable(server)
poller.register_readable(clients[0])
poller.register_readable(clients[1])


# send a message from each client to the server
error_check(clients[0].send_string('', ZMQ::SNDMORE))
error_check(clients[0].send_string('hello from client 1'))

error_check(clients[1].send_string('', ZMQ::SNDMORE))
error_check(clients[1].send_string('hello from client 2'))

puts "Main Loop Started"

th = Thread.new do
  end_loop = false
  
  while !end_loop
    # blocking poll, it will only block this thread and will not
    # return until data is available on one of the sockets
    poller.poll
    
    # poller.readables includes all the sockets where data is
    # available
    identity = ''
    delimiter = ''
    msg = ''
    poller.readables.each do |s|
      case s
      when server
        # destination's identity
        error_check(s.recv_string(identity))
        # just a blank message to separate
        # headers from data
        error_check(s.recv_string(delimiter))
        # data can include more than a single part
        error_check(s.recv_string(msg))
        puts "Server: #{identity} sent <#{msg}>"
        
        if msg == "exit"
          end_loop = true
        else
          error_check(server.send_string(identity, ZMQ::SNDMORE))
          error_check(server.send_string("", ZMQ::SNDMORE))
          error_check(server.send_string("Hello #{identity}, nice to meet you !"))
        end
    
      when clients[0]
        # for XREQ sockets you do not receive the identity of
        # the server which answered the request so the message parts
        # start with the blank delimiter
        error_check(s.recv_string(delimiter))
        error_check(s.recv_string(msg))
        puts "Client1 received '#{msg}'"
      
      when clients[1]
        error_check(s.recv_string(delimiter))
        error_check(s.recv_string(msg))
        puts "Client2 received '#{msg}'"
      
      end
    end
  end
end

# the following shows that the call to poll do not block
# our whole process but only the calling thread
sleep(1)

error_check(server.send_string("client2", ZMQ::SNDMORE))
error_check(server.send_string("", ZMQ::SNDMORE))
error_check(server.send_string('i am watching you !'))

sleep(1)

error_check(clients[1].send_string('', ZMQ::SNDMORE))
error_check(clients[1].send_string('exit'))

th.join()


# A successful run looks like:

#$ ruby 007_xreq_xrep.rb 
#Main Loop Started
#Server: client1 sent <hello from client 1>
#Server: client2 sent <hello from client 2>
#Client1 received 'Hello client1, nice to meet you !'
#Client2 received 'Hello client2, nice to meet you !'
#Client2 received 'i am watching you !'
#Server: client2 sent <exit>
