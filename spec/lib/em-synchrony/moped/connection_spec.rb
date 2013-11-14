# encoding: utf-8
require 'spec_helper'

require 'moped'
require 'em-synchrony/moped'

describe Moped::Connection do
  it 'should have patches included' do
    expect { Moped::Sockets::EmTCP }.not_to raise_error(NameError)
  end

  let(:mongod_options) { {} }
  let(:server) { FakeMongodServer.new(mongod_options) }
  let(:server_port) { server.port }
  after { server.stop }

  let(:options) { {} }
  let(:conn) do
    timeout = 1
    host = options.delete(:host) || '127.0.0.1'
    port = options.delete(:port) || server_port
    Moped::Connection.new(host, port, timeout, options)
  end

  shared_context 'common connection' do
    context 'with a running server' do
      it 'should connect' do
        expect(conn.connect).to be_a(connection_class)
      end
    end

    context 'with an unresponsive host' do
      # 127.0.0.2 seems to timeout for my tests...
      let(:options) { { host: ENV['TIMEOUT_HOST'] } }
      it 'should raise a timeout error' do
        expect { conn.connect }.to raise_error(
          Moped::Errors::ConnectionFailure,
          /^Timed out connection to Mongo on/)
      end
    end

    context 'without a server' do
      let(:options) { { port: 2 } }
      it 'should raise a connection error on connection refused' do
        server.stop
        expect { conn.connect }.to raise_error(
          Moped::Errors::ConnectionFailure, /ECONNREFUSED/)
      end
    end
  end

  context 'evented' do
    include_context 'with em-synchrony'
    let(:connection_class) { Moped::Sockets::EmTCP }
    include_context 'common connection'
    context 'with ssl' do
      let(:ssl_options) { nil }
      let(:options) { { ssl: ssl_options } }
      let(:mongod_options) do
        {
          ssl: {
            private_key_file: "#{SSL_DIR}/server.key",
            cert_chain_file: "#{SSL_DIR}/server.crt",
            verify_peer: false
          }
        }
      end

      context 'without specifying ssl' do
        let(:ssl_options) { nil }
        let(:options) { {} }
        it 'should connect (though comms will fail later)' do
          expect(conn.connect).to be_a(Moped::Sockets::EmTCP)
        end
      end

      context 'and a server with a trusted certificate' do
        context 'when specifying ssl: true' do
          let(:ssl_options) { true }
          it 'should connect' do
            expect(conn.connect).to be_a(Moped::Sockets::EmSSL)
          end
        end

        context 'when specifying ssl: {}' do
          let(:ssl_options) { {} }
          it 'should connect' do
            expect(conn.connect).to be_a(Moped::Sockets::EmSSL)
          end
        end

        context 'when not verifying peer' do
          let(:ssl_options) { { verify_peer: false } }
          it 'should connect' do
            expect(conn.connect).to be_a(Moped::Sockets::EmSSL)
          end
        end

        context 'when verifying peer' do
          context 'and no certificate provided' do
            let(:ssl_options) { { verify_peer: true } }
            it 'should raise an error' do
              expect { conn.connect }
                .to raise_error(
                  Moped::Errors::ConnectionFailure,
                  /Failed to verify SSL certificate of peer/
                )
            end
          end

          context 'and a certificate is provided' do
            context 'and verify_host is not provided' do
              let(:ssl_options) do
                {
                  verify_peer: true,
                  verify_cert: "#{SSL_DIR}/ca_cert.pem"
                }
              end
              it 'should raise an error' do
                expect { conn.connect }
                  .to raise_error(
                    Moped::Errors::ConnectionFailure,
                    /Failed to verify SSL certificate of peer/
                  )
              end
            end
            context 'and verify_host does not match the server cert' do
              let(:ssl_options) do
                {
                  verify_peer: true,
                  verify_cert: "#{SSL_DIR}/ca_cert.pem",
                  verify_host: 'remotehost'
                }
              end
              it 'should raise an error' do
                expect { conn.connect }
                  .to raise_error(
                    Moped::Errors::ConnectionFailure,
                    /Failed to verify SSL certificate of peer/
                  )
              end
            end
            context 'and verify_host matches the server cert' do
              let(:ssl_options) do
                {
                  verify_peer: true,
                  verify_cert: "#{SSL_DIR}/ca_cert.pem",
                  verify_host: 'localhost'
                }
              end
              it 'should connect' do
                expect(conn.connect).to be_a(Moped::Sockets::EmSSL)
              end
            end
          end # 'and a certificate is provided'
        end # 'when verifying peer'
      end # server with a trusted certificate
      context 'and a server with an untrusted certificate' do
        let(:mongod_options) do
          {
            ssl: {
              private_key_file: "#{SSL_DIR}/untrusted.key",
              cert_chain_file: "#{SSL_DIR}/untrusted.crt",
              verify_peer: false
            }
          }
        end

        context 'when specifying ssl: true' do
          let(:ssl_options) { true }
          it 'should connect' do
            expect(conn.connect).to be_a(Moped::Sockets::EmSSL)
          end
        end

        context 'when specifying ssl: {}' do
          let(:ssl_options) { {} }
          it 'should connect' do
            expect(conn.connect).to be_a(Moped::Sockets::EmSSL)
          end
        end

        context 'when not verifying peer' do
          let(:ssl_options) { { verify_peer: false } }
          it 'should connect' do
            expect(conn.connect).to be_a(Moped::Sockets::EmSSL)
          end
        end

        context 'when verifying peer' do
          context 'and no certificate provided' do
            let(:ssl_options) { { verify_peer: true } }
            it 'should raise an error' do
              expect { conn.connect }
                .to raise_error(
                  Moped::Errors::ConnectionFailure,
                  /Failed to verify SSL certificate of peer/
                )
            end
          end

          context 'and a certificate is provided' do
            context 'and verify_host is not provided' do
              let(:ssl_options) do
                {
                  verify_peer: true,
                  verify_cert: "#{SSL_DIR}/ca_cert.pem"
                }
              end
              it 'should raise an error' do
                expect { conn.connect }
                  .to raise_error(
                    Moped::Errors::ConnectionFailure,
                    /Failed to verify SSL certificate of peer/
                  )
              end
            end
            context 'and verify_host does not match the server cert' do
              let(:ssl_options) do
                {
                  verify_peer: true,
                  verify_cert: "#{SSL_DIR}/ca_cert.pem",
                  verify_host: 'remotehost'
                }
              end
              it 'should raise an error' do
                expect { conn.connect }
                  .to raise_error(
                    Moped::Errors::ConnectionFailure,
                    /Failed to verify SSL certificate of peer/
                  )
              end
            end
            context 'and verify_host matches the server cert' do
              let(:ssl_options) do
                {
                  verify_peer: true,
                  verify_cert: "#{SSL_DIR}/ca_cert.pem",
                  verify_host: 'localhost'
                }
              end
              it 'should raise an error' do
                expect { conn.connect }
                  .to raise_error(
                    Moped::Errors::ConnectionFailure,
                    /Failed to verify SSL certificate of peer/
                  )
              end
            end
          end # 'and a certificate is provided'
        end # 'when verifying peer'
      end # 'and a server with an untrusted certificate'
    end # 'with ssl'
  end # 'evented'

  context 'threaded' do
    include_context 'without em-synchrony'
    let(:connection_class) { Moped::Sockets::TCP }
    include_context 'common connection'
  end

end
