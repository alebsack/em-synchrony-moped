# encoding: utf-8
require 'spec_helper'

require 'moped'
require 'em-synchrony/moped'

# TODO: clean up a bit.  we're basically testing Connection through Node.
# we should be able to test Connection by itself.

describe Moped::Connection do
  it 'should have patches included' do
    expect { Moped::Sockets::EmTCP }.not_to raise_error(NameError)
  end

  let(:mongod_options) { {} }
  let(:server) { FakeMongodServer.new(mongod_options) }
  let(:server_port) { server.port }
  after { server.stop }

  let(:node_options) { {} }
  let(:node) do
    options = node_options.merge(timeout: 1)
    host = options.delete(:host) || 'localhost'
    Moped::Node.new("#{host}:#{server_port}", options)
  end

  shared_context 'common connection' do
    context 'with a running server' do
      it 'should connect' do
        node.refresh
        node.should be_primary
        node.should be_connected
      end

      it 'should detect a disconnect' do
        node.refresh
        node.should be_primary
        node.should be_connected
        server.stop
        expect do
          node.command('admin', ismaster: 1)
        end.to raise_error(
          Moped::Errors::ConnectionFailure # TODO: check the message
        )
        node.should_not be_connected
      end
    end

    context 'with an unpresponsive host' do
      # 127.0.0.2 seems to timeout for my tests...
      let(:node_options) { { host: ENV['TIMEOUT_HOST'] } }
      it 'should raise a timeout error' do
        expect { node.refresh }.to raise_error(
          Moped::Errors::ConnectionFailure,
          /^Timed out connection to Mongo on/)
      end
    end

    context 'without a server' do
      it 'should raise a connection error on connection refused' do
        server.stop
        expect { node.refresh }.to raise_error(
          Moped::Errors::ConnectionFailure, /ECONNREFUSED/)
      end
    end
  end

  shared_context 'common connection ssl' do
    context 'with ssl server' do
      let(:mongod_options) do
        {
          ssl: {
            private_key_file: "#{SSL_DIR}/server.key",
            cert_chain_file: "#{SSL_DIR}/server.crt",
            verify_peer: false
          }
        }
      end

      context 'without verifying peer' do
        let(:node_options) { { ssl: { verify_peer: false } } }
        it 'should connect' do
          node.refresh
          node.should be_primary
        end
      end

      context 'when verifying peer' do
        let(:node_options) do
          { ssl: {
              verify_peer: true,
              verify_cert: "#{SSL_DIR}/ca_cert.pem",
              verify_host: 'localhost'
            }
          }
        end
        it 'should connect' do
          node.refresh
          node.should be_primary
        end

        context 'with untrusted key on server' do
          let(:mongod_options) do
            {
              ssl: {
                private_key_file: "#{SSL_DIR}/untrusted.key",
                cert_chain_file: "#{SSL_DIR}/untrusted.crt",
                verify_peer: false
              }
            }
          end

          it 'should connect and fail to verify peer' do
            expect do
              node.refresh
              node.should be_primary
            end.to raise_error(
              Moped::Errors::ConnectionFailure,
              /Failed to verify SSL certificate of peer/
            )
          end
        end
      end
    end
  end

  context 'evented' do
    include_context 'with em-synchrony'
    include_context 'common connection'
    include_context 'common connection ssl'
  end
  context 'threaded' do
    include_context 'without em-synchrony'
    include_context 'common connection'
  end

end
