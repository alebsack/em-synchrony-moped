# encoding: utf-8

require 'moped/address'
require 'em-dns-resolver'
require 'fiber'

module Moped
  class Address

    alias_method :super_resolve, :resolve
    # Override to support non-blocking DNS requests
    def resolve(node)
      return super_resolve(node) unless EventMachine.reactor_thread?
      em_each_address(host).each do |ip|
        if ip =~ Resolv::IPv4::Regex
          @ip ||= ip
          break
        end
      end
      raise Resolv::ResolvError unless @ip
      @resolved ||= "#{ip}:#{port}"
    rescue Timeout::Error, Resolv::ResolvError, SocketError
      Loggable.warn("  MOPED:", "Could not resolve IP for: #{original}", "n/a")
      node.down! and false
    end

    def em_each_address(value)
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
        fiber.resume(Resolv::ResolvError.new(a.inspect))
      end
      result = Fiber.yield
      fail result if result.is_a?(StandardError)
      result
    end

  end
end