# encoding: utf-8

shared_context 'with em-synchrony' do
  around(:each) do |example|
    require 'em-synchrony'
    EventMachine.error_handler do |e|
      puts "Error in Eventmachine: #{e.inspect}"
      EM.stop
    end
    EventMachine.synchrony do
      example.run
      EM.stop if EM.reactor_running?
    end
  end
end

shared_context 'without em-synchrony' do
  before(:each) do
    EventMachine.error_handler do |e|
      puts "Error in Eventmachine: #{e.inspect}"
      EM.stop
    end
    queue = Queue.new
    @em_thread = Thread.new { EventMachine.run { queue << true } }
    queue.pop
  end

  after(:each) do
    EM.stop
    @em_thread.join
  end
end
