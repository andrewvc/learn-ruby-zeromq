# Learn ZeroMQ by example! #

## A Work in Progress ##

If you'd like to help write examples, or if you've found an error, please write me, or fork and patch this repo.
I'm still new to ZeroMQ myself, so some stuff may not be so perfect. If there are any errors, please send in a patch!

## About ZeroMQ ##

ZeroMQ is one of the most exciting technologies emerging today. Follow along with these tutorials explaining the usage of the ffi-rzmq gem.

Be sure to follow them in order, as concepts shown in earlier chapters won't be described later on.

## Getting Started ##

1. Get a functioning ruby, either jruby (recommended) or 1.9.2. I recommend using [rvm](http://rvm.beginrescueend.com/) to manage multiple rubies
2. If you're using jruby the ffi gem it comes with will work fine. **If using 1.9.2 you MUST install the special ffi gem** included here, or build it from HEAD yourself.
3. Download and install ZeroMQ from the ZeroMQ [download page](http://www.zeromq.org/area:download). `./configure && make && make install`
4. `gem install ffi-rzmq zmqmachine`. Make sure you have the ffi-rzmq gem >= 0.5.1 . 

now You're set! Follow the numbered examples in order.

## Thanks Chuck! ##

Many thanks to [Chuck Remes](http://github.com/chuckremes), author of both [ffi-rzmq](http://github.com/chuckremes/ffi-rzmq) and [zmqmachine](http://github.com/chuckremes/zmqmachine) for providing the ruby community with these gems, and helping answer my questions. None of this, would  have been possible without his efforts.
