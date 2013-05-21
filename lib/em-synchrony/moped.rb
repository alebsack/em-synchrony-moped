require "moped/connection"
require "moped/node"
require 'em-resolv-replace'

silence_warnings do
  module Moped
    class Cluster
      def sleep(seconds)
        EM::Synchrony.sleep(seconds)
      end

      # MONKEY PATCH: if all available connections are down, use the seeds
      # again to determine, where the application should connect. This is a
      # implementation detail and unlikely to be main line. Therefore no pull
      # request here. The assumtion is, that if we can't connect to any mongodb
      # that they are relocated and available under a different DNS address.
      def nodes(opts = {})
        current_time = Time.new
        down_boundary = current_time - down_interval
        refresh_boundary = current_time - refresh_interval

        # Find the nodes that were down but are ready to be refreshed, or those
        # with stale connection information.
        needs_refresh, available = @nodes.partition do |node|
          node.down? ? (node.down_at < down_boundary) : node.needs_refresh?(refresh_boundary)
        end

        # Refresh those nodes.
        available.concat refresh(needs_refresh)

        # Now return all the nodes that are available and participating in the
        # replica set.
        avail_not_down = available.reject do |node|
          node.down? || !member?(node) || (!opts[:include_arbiters] && node.arbiter?)
        end

        if avail_not_down.empty?
          if logger = Moped.logger
            logger.warn " MOPED: reinitialize cluster because all nodes " \
                        "are down with #{@seeds.inspect}"
          end
          @nodes = @seeds.map { |host| Node.new(host, @options) }
        end

        avail_not_down
      end
    end

    class Node
      # Override to support non-blocking DNS requests
      def parse_address
        host, port = address.split(":")
        @port = (port || 27017).to_i

        @resolver ||= Resolv.new([Resolv::Hosts.new, Resolv::DNS.new])

        # For now, limit the IPs only to IPv4 hosts.  In order to support IPv6,
        # the node should be able to handle fallback connections.
        @resolver.getaddresses(host).each do |ip|
          if ip =~ Resolv::IPv4::Regex
            @ip_address = ip
            break
          end
        end
        @resolved_address = "#{@ip_address}:#{@port}"
      end
    end


    class Connection
      def connect
        @sock = if !!options[:ssl]
          Sockets::SSL.connect(host, port, timeout, options)
        else
          Sockets::TCP.connect(host, port, timeout, options)
        end
      end
    end

    Sockets.send(:remove_const, :TCP)
    Sockets.send(:remove_const, :SSL)
    module Sockets
      module Connectable
        attr_accessor :options

        def alive?
          !closed?
        end

        module ClassMethods

          def connect(host, port, timeout, options={})
            socket = EM.connect(host, port, self) do |c|
              c.pending_connect_timeout = timeout
              c.comm_inactivity_timeout = timeout
              c.options = options.merge(:host => host)
            end
            # In TCPSocket, new against a closed port raises Errno::ECONNREFUSED.
            # In EM, connect against a closed port result in a call to unbind with
            # a reason param of Errno::ECONNREFUSED as a class, not an instance.
            unless socket.sync(:in)  # wait for connection
              raise socket.unbind_reason.new if socket.unbind_reason.is_a? Class
              raise SocketError, socket.unbind_reason
            end
            socket

          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EPIPE, Errno::ECONNRESET, Errno::ETIMEDOUT, IOError => error
            raise Errors::ConnectionFailure, "#{host}:#{port}: #{error.class.name} (#{error.errno}): #{error.message}"
          rescue SocketError => error
            raise Errors::ConnectionFailure, "#{host}:#{port}: #{error.class.name}: #{error.message}"
          rescue OpenSSL::SSL::SSLError => error
            raise Errors::ConnectionFailure, "#{host}:#{port}: #{error.class.name} (#{error.errno}): #{error.message}"
          end


        end
      end

      class TCP < EventMachine::Synchrony::TCPSocket
        include Connectable
      end

      class SSL < EventMachine::Synchrony::TCPSocket
        include Connectable

        def connection_completed
          @verified = false
          if @options[:ssl].is_a?(Hash)
            start_tls(@options[:ssl])
          else
            start_tls
          end
        end

        def ssl_verify_peer(pem)
          unless cert_store = @options[:ssl][:cert_store]
            cert_store = OpenSSL::X509::Store.new
            cert_store.add_file(@options[:ssl][:verify_cert])
          end

          if cert = OpenSSL::X509::Certificate.new(pem) rescue nil
            if cert_store.verify(cert)

              cert.extensions.each do |e|
                if e.oid == 'basicConstraints' && e.value == 'CA:TRUE'
                  return true
                end
              end

              host = @options[:ssl][:verify_host]
              if OpenSSL::SSL.verify_certificate_identity(cert, host)
                @verified = true
                return true
              end
            end
          end

          true
        rescue => e
          unbind "Failed to verify SSL certificate of peer"
          false
        end

        def ssl_handshake_completed
          if @options[:ssl][:verify_peer] && !@verified
            unbind "Failed to verify SSL certificate of peer"
          else
            @opening = false
            @in_req.succeed self
          end
        end

      end
    end
  end
end
