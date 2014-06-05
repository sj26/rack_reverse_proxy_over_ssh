#!/usr/bin/env ruby -S rackup

require "bundler/setup"

require "net/ssh"
require "rack"

require_relative "net-http_over_ssh"
require_relative "net-ssh-service-forward-direct"
require_relative "rack_reverse_proxy"

ssh_uri = URI.parse(ENV["SSH_URI"])
http_uri = URI.parse(ENV["HTTP_URI"])

# Start an SSH session
ssh_host = ssh_uri.host
ssh_user = ssh_uri.userinfo || ENV["USER"]
ssh_port = ssh_uri.port || 22
ssh = Net::SSH.start(ssh_host, ssh_user, port: ssh_port)
ssh_thread = Thread.new { ssh.loop(0.1) { true } }
ssh_thread.abort_on_exception = true

# Log requests
use Rack::CommonLogger

# Reverse proxy through SSH
run RackReverseProxy.new(http_uri, proxy_ssh: ssh)
