require "monitor"
require "net/ssh"

module Net
  module SSH
    module Service
      class Forward
        def direct(remote_host, remote_port)
          client, socket = Socket.pair(:UNIX, :STREAM, 0)

          monitor = Monitor.new
          condition = monitor.new_cond

          bind_address = "127.0.0.1"
          local_port = 0

          info { "establishing direct connection to #{remote_host}:#{remote_port}" }

          channel = session.open_channel("direct-tcpip", :string, remote_host, :long, remote_port, :string, bind_address, :long, local_port) do |ch|
            channel.info { "direct channel established" }
            monitor.synchronize { condition.broadcast }
          end

          prepare_client(client, channel, :direct)

          channel.on_open_failed do |ch, code, description|
            channel.error { "could not establish direct channel: #{description} (#{code})" }
            channel[:socket].close
          end

          monitor.synchronize { condition.wait }

          socket
        end
      end
    end
  end
end
