# encoding: utf-8

shared_context 'with em-synchrony' do
  around(:each) do |example|
    require 'em-synchrony'
    EventMachine.error_handler do |e|
      puts "Error in Eventmachine: #{e.inspect}"
      puts e.backtrace.join("\n")
      EventMachine.stop
    end
    EventMachine.synchrony do
      example.run
      EventMachine.stop if EventMachine.reactor_running?
    end
  end
end

shared_context 'without em-synchrony' do
  before(:each) do
    EventMachine.error_handler do |e|
      puts "Error in Eventmachine: #{e.inspect}"
      puts e.backtrace.join("\n")
      EventMachine.stop
    end
    queue = Queue.new
    @em_thread = Thread.new { EventMachine.run { queue << true } }
    queue.pop
  end

  after(:each) do
    EventMachine.stop
    @em_thread.join
  end
end
