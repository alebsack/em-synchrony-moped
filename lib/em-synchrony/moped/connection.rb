# encoding: utf-8

require 'moped/connection'

module Moped
  # Em-Synchrony overrides for Moped::Connection
  class Connection
    alias_method :super_connect, :connect
    def connect
      return super_connect unless EventMachine.reactor_thread?
      if !!options[:ssl]
        @sock = Socket::EmSSL.em_connect(host, port, timeout, options)
      else
        @sock = Socket::EmTCP.em_connect(host, port, timeout, options)
      end
    end

    module Socket
      module Connectable
        # Class methods to extend the Connectable Class
        module ClassMethods
          def em_connect(host, port, timeout, options)
            socket = EventMachine.connect(host, port, self) do |c|
              c.pending_connect_timeout = timeout
              c.options = options
            end
            # In TCPSocket, new against a closed port raises Errno::ECONNREFUSED.
            # In EM, connect against a closed port result in a call to unbind
            # with a reason param of Errno::ECONNREFUSED as a class, not an
            # instance.
            unless socket.sync(:in)  # wait for connection
              fail socket.unbind_reason.new if socket.unbind_reason.is_a? Class
              fail SocketError, socket.unbind_reason
            end
            socket
          rescue Errno::ETIMEDOUT
            raise Errors::ConnectionFailure,
                  "Timed out connection to Mongo on #{host}:#{port}"
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EPIPE,
                 Errno::ECONNRESET, IOError => error
            fail Errors::ConnectionFailure,
                 "#{host}:#{port}: #{error.class.name} (#{error.errno}): " +
                 "#{error.message}"
          rescue SocketError => error
            fail Errors::ConnectionFailure,
                 "#{host}:#{port}: #{error.class.name}: #{error.message}"
          end
        end
      end

      # The EM-Synchrony flavor of Moped::Socket::TCP
      class EmTCP < EventMachine::Synchrony::TCPSocket
        include Connectable
        attr_accessor :options
        def alive?
          !closed?
        end
      end

      # The EM-Synchrony flavor of Moped::Socket::SSL
      class EmSSL < EmTCP
        def connection_completed
          @verified = false
          @cert_store = ssl_options.delete(:cert_store)
          @cert_store ||= OpenSSL::X509::Store.new
          if (cert_file = ssl_options.delete(:verify_cert))
            @cert_store.add_file(cert_file)
          end
          start_tls(ssl_options)
        end

        def ssl_verify_peer(pem)
          return true unless ssl_options[:verify_peer]
          if (cert = certificate(pem)) && @cert_store.verify(cert)
            # bypass hostname checking for this cert if it's a CA
            return true if cert.extensions.find do |e|
              e.oid == 'basicConstraints' && e.value == 'CA:TRUE'
            end

            @verified = true if (host = ssl_options[:verify_host]) &&
              OpenSSL::SSL.verify_certificate_identity(cert, host)
          end

          # Always return true.  We will evaluate the certificate chain in
          # ssl_handshake_completed.
          true
        end

        def ssl_handshake_completed
          if ssl_options[:verify_peer] && !@verified
            unbind 'Failed to verify SSL certificate of peer'
          else
            @opening = false
            @in_req.succeed self
          end
        end

        private

        def ssl_options
          @ssl_options ||= @options[:ssl] == true ? {} : @options[:ssl] || {}
        end

        def certificate(pem)
          OpenSSL::X509::Certificate.new(pem)
        end
      end # EmSSL
    end
  end
end

puts Moped::Connection::Socket::EmSSL.inspect
