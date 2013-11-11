# encoding: utf-8

require 'spec_helper'

require 'moped'
require 'em-synchrony/moped'

describe Moped::Cluster do
  let(:mongod_options) { {} }
  let(:server1) { FakeMongodServer.new(mongod_options) }
  let(:server1_port) { server1.port }

  let(:server2) { FakeMongodServer.new(mongod_options.merge(master: 0)) }
  let(:server2_port) { server2.port }

  after do
    server1.stop if server1
    server2.stop if server2
  end

  shared_context 'common cluster' do
    let(:options) { {} }
    let(:seeds) do
      ["#{server1.host}:#{server1_port}", "#{server2.host}:#{server2_port}"]
    end
    let(:cluster) { Moped::Cluster.new(seeds, options.merge(timeout: 1)) }

    describe '#with_primary' do
      it 'should get a primary node' do
        cluster.with_primary do |node|
          expect(node).to be_primary
        end
      end
    end

    describe '#with_secondary' do
      it 'should get a secondary node' do
        cluster.with_secondary do |node|
          expect(node).to be_secondary
        end
      end
    end
  end

  context 'evented' do
    include_context 'with em-synchrony'
    include_context 'common cluster'
  end
  context 'threaded' do
    include_context 'without em-synchrony'
    include_context 'common cluster'
  end
end
