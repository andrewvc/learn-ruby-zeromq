
# In this example we have full control on what is sent to who, there is little to no
# documentation on this and that's why I made this example
# We have a server with 2 "clients" speaking to it, each one will have a predefined
# identity allowing to speak to a particular peer


require 'rubygems'
require 'ffi-rzmq'
Thread.abort_on_exception = true

# create context
ctx = ZMQ::Context.new(1)

# our server
server = ctx.socket(ZMQ::XREP)
server.setsockopt(ZMQ::IDENTITY, "server")
server.bind('tcp://127.0.0.1:7777')


# we add the two clients, set their identity and connect them
# to the server
clients = [
    ctx.socket(ZMQ::XREQ),
    ctx.socket(ZMQ::XREQ)
  ]


clients[0].setsockopt(ZMQ::IDENTITY, "client1")
clients[0].connect('tcp://127.0.0.1:7777')

clients[1].setsockopt(ZMQ::IDENTITY, "client2")
clients[1].connect('tcp://127.0.0.1:7777')


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
clients[0].send_string('', ZMQ::SNDMORE)
clients[0].send_string('hello from client 1')

clients[1].send_string('', ZMQ::SNDMORE)
clients[1].send_string('hello from client 2')

puts "Main Loop Started"

th = Thread.new do
  end_loop = false
  
  while !end_loop
    # blocking poll, it will only block this thread and will not
    # return until data is available on one of the sockets
    poller.poll
    
    # poller.readables includes all the sockets where data is
    # available
    poller.readables.each do |s|
      case s
      when server
        # destination's identity
        identity = s.recv_string()
        # just a blank message to separate
        # headers from data
        delimiter = s.recv_string()
        # data can include more than a single part
        msg = s.recv_string()
        puts "Server: #{identity} sent <#{msg}>"
        
        if msg == "exit"
          end_loop = true
        else
          server.send_string(identity, ZMQ::SNDMORE)
          server.send_string("", ZMQ::SNDMORE)
          server.send_string("Hello #{identity}, nice to meet you !")
        end
    
      when clients[0]
        # for XREQ sockets you do not receive the identity of
        # the server which answered the request so the message parts
        # start with the blank delimiter
        delimiter = s.recv_string()
        msg = s.recv_string()
        puts "Client1 received '#{msg}'"
      
      when clients[1]
        delimiter = s.recv_string()
        msg = s.recv_string()
        puts "Client2 received '#{msg}'"
      
      end
    end
  end
end

# the following shows that the call to poll do not block
# our whole process but only the calling thread
sleep(1)

server.send_string("client2", ZMQ::SNDMORE)
server.send_string("", ZMQ::SNDMORE)
server.send_string('i am watching you !')

sleep(1)

clients[1].send_string('', ZMQ::SNDMORE)
clients[1].send_string('exit')

th.join()
