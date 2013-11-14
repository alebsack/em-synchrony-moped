# encoding: utf-8

require 'moped/cluster'

module Moped
  # Our patches to Moped::Cluster
  class Cluster
    def sleep(seconds)
      if EventMachine.reactor_thread?
        EM::Synchrony.sleep(seconds)
      else
        Kernel.sleep(seconds)
      end
    end
  end
end
