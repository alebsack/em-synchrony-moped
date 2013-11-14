# encoding: utf-8
require 'eventmachine'

# Load order here is important.  Message must be loaded so we can
# add deserialization support to moped/protocol/query
require 'moped/protocol/message'

module Moped
  module Protocol
    # This patch is so we can parse a query as a server
    module Message
      module ClassMethods
        alias_method :_old_cstring, :cstring
        def cstring(name)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def deserialize_#{name}(buffer)
              str = ''
              while c = buffer.getc
                break if c == '\0'
                str << c
              end
              self.#{name} = str
            end
          RUBY
          _old_cstring(name)
        end

        alias_method :_old_document, :document
        def document(name, options = {})
          if options[:optional]
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def deserialize_#{name}(buffer)
                # noop for now
              end
            RUBY
          else
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def deserialize_#{name}(buffer)
                self.#{name} = BSON::Document.deserialize(buffer)
              end
            RUBY
          end
          _old_document(name, options)
        end
      end
    end

    # now that the class DSL is patched, load the message classes we need to
    # patch further

    # This patch is so we can parse a query as a server
    require 'moped/protocol/query'
    class Query
      class << self
        def deserialize(buffer)
          reply = allocate
          fields.each do |field|
            reply.__send__ :"deserialize_#{field}", buffer
          end
          reply
        end
      end
    end

    # This patch is so we can create a Reply object as a server
    require 'moped/protocol/reply'
    class Reply
      def initialize(documents, options = {})
        @documents            = documents
        @request_id           = options[:request_id]
        @response_to          = options[:response_to]
        @flags                = options[:flags] || []
        @count                = documents.length
        @op_code              = 1
      end
    end
  end
end

# Eventmachine connection for FakeMongod
class FakeMongod < EventMachine::Connection
  def initialize(options, server)
    @options = {
      master: 1
    }.merge(options)
    @server = server
    @request_id = 0
  end

  def post_init
    @server.add_connection(self)
    start_tls(@options[:ssl]) if @options[:ssl]
  end

  def receive_data(data)
    query = Moped::Protocol::Query.deserialize(StringIO.new(data))
    if query.full_collection_name == 'admin.$cmd'
      if query.selector == { 'ismaster' => 1 }
        if @options[:master] == 1
          send_reply(query, ok: 1, ismaster: 1)
        else
          send_reply(query, ok: 1, secondary: 1)
        end
      elsif query.selector == { 'listDatabases' => 1 }
        send_reply(query, ok: 1, databases: [{ name: 'test_db' }])
      end
    end
  end

  def send_reply(query, *documents)
    @request_id += 1
    reply =  Moped::Protocol::Reply.new(
      documents,
      request_id: @request_ud,
      response_to: query.request_id
    )
    send_data reply.serialize
  end

  def unbind
    @server.remove_connection(self)
  end
end

class FakeMongodServer
  attr_reader :port, :host, :options

  def initialize(options = {})
    @options = {
      host: '127.0.0.1'
    }.merge(options)
    @host = @options.delete(:host)
    @connections = []
    ensure_reactor do
      @server = EventMachine.start_server(
        @host, 0, FakeMongod, @options, self)
      @port = Socket.unpack_sockaddr_in(EventMachine.get_sockname(@server))[0]
    end
  end

  def stop
    return unless @server
    ensure_reactor do
      EventMachine.stop_server(@server)
      # stopping the server only stops the listener. We must now stop
      # all current connections
      @connections.each { |c| c.close_connection }
      @server = nil
    end
  end

  def add_connection(connection)
    @connections << connection
  end

  def remove_connection(connection)
    @connections.delete(connection)
  end

  private

  def ensure_reactor(&block)
    if EventMachine.reactor_thread?
      block.call
    elsif EventMachine.reactor_running?
      queue = Queue.new
      EventMachine.next_tick { queue << block.call }
      queue.pop
    end
  end
end
