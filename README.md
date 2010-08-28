# Learn ZeroMQ by example! #

## A work in progress ##

If you'd like to help write examples, or if you've found an error, please write me, or fork and patch this repo.
I'm still a ZeroMQ noob, so some stuff may not be so perfect. If there are any errors, please send in a patch!

## About ZeroMQ ##

ZeroMQ is one of the most exciting technologies emerging today. Follow along with these tutorials explaining the usage of the ffi-rzmq gem.

Be sure to follow them in order, as concepts shown in earlier chapters won't be described later on.

## Getting Started ##

1. Get a functioning ruby, either jruby (recommended) or 1.9.2. I recommend using rvm to manage multiple rubies
2. If you're using jruby `gem install ffi` will work fine. **If using 1.9.2 you MUST install the special ffi gem** included here, or build it from HEAD yourself.
3. Download and install ZeroMQ from the ZeroMQ [download page](http://www.zeromq.org/area:download). `./configure && make && make install`
4. Install the ffi-rzmq gem included in this repo's gems dir, or build it straight from HEAD yourself.
5. You're set! Follow the numbered examples in order.
