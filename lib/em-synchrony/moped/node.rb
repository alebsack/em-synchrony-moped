# encoding: utf-8

require 'moped/node'
require 'em-dns-resolver'
require 'fiber'

module Moped
  # Our monkey patches to Moped::Node
  module EventedNode
    # Override to support non-blocking DNS requests
    def parse_address
      return super if EM.reactor_thread?
      host, port = address.split(':')
      @port = (port || 27_017).to_i

      @ip_address = em_lookup_address(host)
      fail SocketError unless @ip_address
      @resolved_address = "#{@ip_address}:#{@port}"
    rescue Resolv::ResolvError
      raise SocketError
    end

    def em_lookup_address(value)
      # Lookup in /etc/hosts
      result = []
      @hosts ||= Resolv::Hosts.new
      @hosts.send(:each_address, value) { |x| result << x.to_s }
      return result unless result.empty?

      # Nothing, hit DNS
      fiber = Fiber.current
      df = EM::DnsResolver.send(:resolve, value)
      df.callback do |a|
        fiber.resume(a)
      end
      df.errback do |*a|
        fiber.resume(ResolvError.new(a.inspect))
      end
      result = Fiber.yield
      raise result if result.is_a?(StandardError)
      result
    end
  end

  class Node
    include EventedNode
  end
end
