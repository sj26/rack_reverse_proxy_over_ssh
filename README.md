# Rack Reverse Proxy Over SSH

We have an internal server that I keep having to `ssh -qfN` into, and then change all the URLs linking to the internal URL. Instead, I'd like [Pow](http://pow.cx/) to take care of it.

So I scratched my itch. This rackup config creates an SSH session using [Net::SSH](https://github.com/net-ssh/net-ssh) and uses direct tcpip channels to proxy to the HTTP server on the other side. This means you don't have to use an actual port or anything. This did require extending Net::SSH, but maybe I'll send them a patch.

Running pow using launchd means that it is inside your use session, which means it can use your ssh agent -- no further authentication should be neccessary!

I tried using the [rack-reverse-proxy gem](https://github.com/jaswope/rack-reverse-proxy) but found it was hopelessly overcomplicated. I extracted what I needed and stuffed it into a new class, RackReverseProxy.

There's no way to tell Net::HTTP how to open a socket, so I had to subclass it and mess around a bit.

But, it works! an SSH_URI and HTTP_URI must be set in ENV. Copy the `.env.example` to `.powenv` if you're using pow, or `.rbenv-vars` if using rbenv, or however you like, and customise it.

I like the idea of using this to easily forward just an API or something from a potentially-private server onto your local machine within a JavaScript frontend project or similar, too, so might generify it a bit and get it into gems.
