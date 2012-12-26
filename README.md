# Learn ZeroMQ by Example! #

## A Work in Progress ##

If you'd like to help write examples, or if you've found an error, please write me, or fork and patch this repo.

## About ZeroMQ ##

ZeroMQ is one of the simplest and most exciting ways to build high performance, concurrent local and network applications.
ZeroMQ uses a sockets style API to make powerful message-based programs fun to build.

Be sure to follow the examples in order, as concepts shown in earlier chapters won't be described later on.

## Getting Started ##

1. Get a functioning ruby, either jruby (recommended) or 1.9.2. I recommend using [rvm](http://rvm.beginrescueend.com/) to manage multiple rubies
2. If you're using jruby the ffi gem it comes with will work fine. **If using 1.9.2 you MUST install the special ffi gem**.
3. Download and install ZeroMQ from the ZeroMQ [download page](http://www.zeromq.org/area:download). `./configure && make && make install`
4. `gem install ffi ffi-rzmq zmqmachine`. Make sure you have the ffi-rzmq gem >= 0.9.0 . All examples have been updated to use the newer API exposed in ffi-rzmq 0.9.0 and later. If your libzmq version >= 3.2.1, Make sure you have the ffi-rzmq gem >= 0.9.7(you can clone [git://github.com/chuckremes/ffi-rzmq.git](https://github.com/chuckremes/ffi-rzmq) and build from source), otherwise you will get "Function 'zmq_ctx_set_monitor' not found" error message.

Now you're set! Follow the numbered examples in order, where there are no numbers, there is no order.

## Thanks Chuck! ##

Many thanks to [Chuck Remes](http://github.com/chuckremes), author of both [ffi-rzmq](http://github.com/chuckremes/ffi-rzmq) and [zmqmachine](http://github.com/chuckremes/zmqmachine) for providing the ruby community with these gems, and helping answer my questions. None of this, would  have been possible without his efforts.
