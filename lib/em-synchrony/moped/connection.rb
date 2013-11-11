# encoding: utf-8

module Moped
  class Connection
    def connect
      if EventMachine.reactor_thread?
        if !!options[:ssl]
          @sock = Sockets::EmSSL.em_connect(host, port, timeout, options)
        else
          @sock = Sockets::EmTCP.em_connect(host, port, timeout, options)
        end
      else # use old driver
        if !!options[:ssl]
          @sock = Sockets::SSL.connect(host, port, timeout)
        else
          @sock = Sockets::TCP.connect(host, port, timeout)
        end
      end
    end
  end # class Cnnection

  module Sockets
    module Connectable
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
          fail Errors::ConnectionFailure,
               "Timed out connection to Mongo on #{host}:#{port}"
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EPIPE,
               Errno::ECONNRESET, IOError => error
          fail Errors::ConnectionFailure,
               "#{host}:#{port}: #{error.class.name} (#{error.errno}): " +
               "#{error.message}"
        rescue SocketError => error
          fail Errors::ConnectionFailure,
               "#{host}:#{port}: #{error.class.name}: #{error.message}"
        rescue OpenSSL::SSL::SSLError => error
          fail Errors::ConnectionFailure,
               "#{host}:#{port}: #{error.class.name} (#{error.errno}): " +
               "#{error.message}"
        end
      end
    end

    # The EM-Synchrony flavor of Moped::Sockets::TCP
    class EmTCP < EventMachine::Synchrony::TCPSocket
      include Connectable

      # TODO: re-evaluate the options call.  Can't we pass the caller
      # up to the connection or something?
      attr_accessor :options

      def alive?
        !closed?
      end
    end

    # The EM-Synchrony flavor of Moped::Sockets::SSL
    class EmSSL < EmTCP
      def connection_completed
        @verified = false
        if @options[:ssl].is_a?(Hash)
          start_tls(@options[:ssl])
        else
          start_tls
        end
      end

      def ssl_verify_peer(pem)
        unless (cert_store = @options[:ssl][:cert_store])
          cert_store = OpenSSL::X509::Store.new
          cert_store.add_file(@options[:ssl][:verify_cert])
        end

        if (cert = OpenSSL::X509::Certificate.new(pem) rescue nil)
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
      rescue
        unbind 'Failed to verify SSL certificate of peer'
        false
      end

      def ssl_handshake_completed
        if @options[:ssl][:verify_peer] && !@verified
          unbind 'Failed to verify SSL certificate of peer'
        else
          @opening = false
          @in_req.succeed self
        end
      end
    end
  end
end
