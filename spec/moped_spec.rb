require 'spec_helper'

require 'moped'
require 'em-synchrony/moped'

describe "em-synchrony/moped" do
  
  def new_node(options={})
    options.merge!(:timeout => 1)
    host = options.delete(:host) || 'localhost'
    Moped::Node.new("#{host}:#{FakeMongodHelper::BASE_PORT}", options)
  end
  
  context "without ssl" do
    
    it "should connect" do
      EventMachine.synchrony do
        start_mongod
        
        node = new_node
        node.refresh
        node.should be_primary
        EM.stop
      end
    end
    
    
    it "should raise a connection error on timeout" do
      lambda {
        EventMachine.synchrony do
          start_mongod
          
          # google.com seems timeout for my tests...
          node = new_node(:host => "google.com")
          node.refresh

          EM.stop
        end
      }.should raise_exception(Moped::Errors::ConnectionFailure, /ETIMEDOUT/)
    end

    it "should raise a connection error on connection refused" do
      lambda {
        EventMachine.synchrony do
          new_node.refresh
          EM.stop
        end
      }.should raise_exception(Moped::Errors::ConnectionFailure, /ECONNREFUSED/)
    end
  end
  
  context "without ssl" do
    it "should connect and not verify peer" do
      EventMachine.synchrony do
        start_mongod(
          :ssl => {
            :private_key_file => "#{SSL_DIR}/server.key",
            :cert_chain_file => "#{SSL_DIR}/server.crt",
            :verify_peer => false
          }
        )
        
        node = new_node(:ssl => {:verify_peer => false})
        node.refresh 
        node.should be_primary
        
        EM.stop
      end
    end
    
    it "should connect and verify peer" do
      EventMachine.synchrony do
        start_mongod(
          :ssl => {
            :private_key_file => "#{SSL_DIR}/server.key",
            :cert_chain_file => "#{SSL_DIR}/server.crt",
            :verify_peer => false
          }
        )
        
        node = new_node(:ssl => {
          :verify_peer => true,
          :verify_cert => "#{SSL_DIR}/ca_cert.pem",
          :verify_host => "localhost"
        })
        node.refresh 
        node.should be_primary
        
        EM.stop
      end
    end


    it "should connect and fail to verify peer" do
      lambda {
        
        EventMachine.synchrony do
          start_mongod(
            :ssl => {
              :private_key_file => "#{SSL_DIR}/untrusted.key",
              :cert_chain_file => "#{SSL_DIR}/untrusted.crt",
              :verify_peer => false
            }
          )

          node = new_node(:ssl => {
            :verify_peer => true,
            :verify_cert => "#{SSL_DIR}/ca_cert.pem",
            :verify_host => "localhost"
          })
          
          node.refresh 
          node.should be_primary
          
          EM.stop
        end
      }.should raise_exception(Moped::Errors::ConnectionFailure, /Failed to verify SSL certificate of peer/)
    end
    
    
  end
  
  
end