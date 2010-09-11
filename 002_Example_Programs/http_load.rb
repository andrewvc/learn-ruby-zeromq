#!/usr/bin/env ruby

# PROGRAM OVERVIEW
# 
# In this example we're going to build a real program, a website load tester.
# We'll use ZeroMQ to build not just any web-site traffic simulator, one that can
# easily distribute its workload over an arbitrary number of workers running on any
# number of servers.
#
# We're going to implement this using PUSH/PULL sockets exclusively, the basic
# architecture of our application is going to look like the following
#                               _______________________
#                              |    Task Distributor   |
#                              |________[PUSH]_________|
#                       ______/___     ____|_____     __\_______ 
#                      |  [PULL]  |   |  [PULL]  |   |  [PULL]  |
#                      | Worker 1 |   | Worker 2 |   | Worker N |
#                      |__[PUSH]__|   |__[PUSH]__|   |__[PUSH]__|
#                              \___________|___________/
#                              |        [PULL]         |
#                              |____Result Collector___|
#
# Since PUSH/PULL sockets load balance all their messages among connected peers, 
# tasks sent out from the distributor will be round-robin balanced among connected workers. 
#
# Our program will be setup to run in one of two modes, determined by a command line switch
# 1. A 'control' mode, that runs the
#    Task distributor and result collector.
# 2. A Worker mode, that can spawn an arbitrary number of workers
#
# We're also going to encapsulate all our messages using BERT, a binary serialization format
# that works fantastically with ZeroMQ. Using BERT, we can package up most ruby datatypes in
# an efficient, easy to work with, format, that transmits perfectly across the wire. 
#
# For more information about BERT, visit http://bert-rpc.org/
#
# RUNNING:
#
# You'll need a webserver to test this against, one that you don't mind slamming with requests
# Feel free to substitute 'localhost' in the example below with your own server
#
# 
# Open up two terminals, then run the following two commands in them at the same time 
#
# Startup 6 Workers
# $ ./http_load.rb worker 127.0.0.1 6 #Note: Do NOT use a hostname instead of an IP, IPs only!
#
# Issue 30 requests to your workers
# $ ./http_load.rb control 127.0.0.1 30 http://localhost/ http://localhost/test_url2 http://localhost/test_url3
#
# For fun, try starting up more than one worker process. For even more fun, try distributing the workers on 
# different machines, and connect back to the same control process.

require 'rubygems'
require 'ffi-rzmq'
require 'bert'
require 'net/http'
Thread.abort_on_exception = true

##
## Setup
##
ZCTX = ZMQ::Context.new(1) 
trap "INT", proc { ZCTX.terminate; exit }

def run_app

  # CLI Args
  mode = ARGV[0]

  # Hostname of the control server
  control_host = ARGV[1]
  dist_addr   = "tcp://#{control_host}:2100"
  coll_addr   = "tcp://#{control_host}:2101"

  case mode
  when 'control'
    num_reqs    = ARGV[2].to_i
    urls        = ARGV[3..-1] 
    
    HLoadControl.new(dist_addr,coll_addr,num_reqs,urls).run
  when 'worker'
    num_workers = ARGV[2].to_i
    
    HLoadWorkerMaster.new(dist_addr,coll_addr,num_workers).run
  else
    raise "Unknown mode"
  end
end

##
## Control Server
##

class HLoadControl
  def initialize(dist_addr,coll_addr,num_reqs,urls)
    @dist_addr = dist_addr
    @coll_addr = coll_addr
    @num_reqs  = num_reqs
    @urls      = urls
  end

  def run
    self.start_distributor #Fires off requests to all workers
    self.start_collector   #Blocks till all responses received
     
    ZCTX.terminate
  end

  def start_distributor
   Thread.new do
      dist_sock = ZCTX.socket(ZMQ::PUSH)
      dist_sock.bind(@dist_addr)
      
      i = 0
      puts "Distributor Started"
      while @num_reqs == 0 || i < @num_reqs
        i += 1
         
        message = {:url => @urls[rand(@urls.length)]}
        dist_sock.send_string(BERT.encode(message)) #Blocks until first client connects
        
        print '-'
      end
    end   
  end
  
  def start_collector
    coll_thread = Thread.new do
      coll_sock = ZCTX.socket(ZMQ::PULL)
      coll_sock.bind(@coll_addr)
      
      i = 0
      runtime_sum    = 0
      http_err_count = 0
      puts "Collector Started"
      while (@num_reqs == 0 || i < @num_reqs) && result_str = coll_sock.recv_string
        result = BERT.decode(result_str)
                 
        case result[:status]
        when :success
          print '.'
          runtime_sum += result[:runtime]
          if result[:http_status] >= 400 || result[:http_status] == 0
            puts "HTTP Error: #{result.inspect}"
            http_err_count += 1
          end
        when :error
          $stderr.puts result.inspect
        end
        
        i += 1
      end

      puts "\nAll responses received."
      puts "AVG response time: #{runtime_sum / i.to_f}."
      puts "#{http_err_count} HTTP errors"
    end

    #Wait till we have all our responses
    coll_thread.join
  end
end

##
## Worker Server
##

class HLoadWorkerMaster
  def initialize(dist_addr,coll_addr,num_workers)
    @dist_addr   = dist_addr
    @coll_addr   = coll_addr
    @num_workers = num_workers
  end

  def run
    worker_threads = []
     
    @num_workers.times do |i|
      worker_threads = Thread.new do
        self.work(i)
      end
    end
    
    worker_threads.join
  end
  
  def work(worker_id)
    puts "Started Worker #{worker_id}"
    dist_sock = ZCTX.socket(ZMQ::PULL)
    dist_sock.connect(@dist_addr)
    
    coll_sock = ZCTX.socket(ZMQ::PUSH)
    coll_sock.connect(@coll_addr)
    
    begin
      while input_str = dist_sock.recv_string
        print '.'
         
        input = BERT.decode(input_str)
        url = input[:url]
        
        #Start building our output message
        output = {:url => url, :worker_id => worker_id}
        
        begin
          req_start = Time.now
          uri       = URI.parse(url)
          http_resp = nil
          Net::HTTP.start(uri.host, uri.port) do |http|
            http_resp = http.request_get(uri.path)
          end
          runtime   = Time.now - req_start
           
          output[:status]      = :success
          output[:runtime]     = runtime
          output[:http_status] = http_resp['status'].to_i
        rescue StandardError => e
          output[:status]  = :error
          output[:message] = "P#{worker_id} Error: '#{e.message}'"
        end
        
        coll_sock.send_string(BERT.encode(output))
      end
    rescue ZMQ::SocketError => e
      puts e.inspect
    end
  end
end

run_app
