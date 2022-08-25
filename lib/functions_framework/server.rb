# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "json"
require "monitor"

require "puma"
require "puma/server"
require "rack"

module FunctionsFramework
  ##
  # A web server that wraps a function.
  #
  class Server
    include ::MonitorMixin

    ##
    # Create a new web server given a function definition, a set of application
    # globals, and server configuration.
    #
    # To configure the server, pass a block that takes a
    # {FunctionsFramework::Server::Config} object as the parameter. This block
    # is the only opportunity to modify the configuration; once the server is
    # initialized, configuration is frozen.
    #
    # @param function [FunctionsFramework::Function] The function to execute.
    # @param globals [Hash] Globals to pass to invocations. This hash should
    #     normally be frozen so separate function invocations cannot interfere
    #     with one another's globals.
    # @yield [FunctionsFramework::Server::Config] A config object that can be
    #     manipulated to configure this server.
    #
    def initialize function, globals
      super()
      @config = Config.new
      yield @config if block_given?
      @config.freeze
      @function = function
      @app =
        case function.type
        when :http
          HttpApp.new function, globals, @config
        when :cloud_event
          EventApp.new function, globals, @config
        else
          raise "Unrecognized function type: #{function.type}"
        end
      @server = nil
      @signals_installed = false
    end

    ##
    # The function to execute.
    # @return [FunctionsFramework::Function]
    #
    attr_reader :function

    ##
    # The final configuration. This is a frozen object that cannot be modified.
    # @return [FunctionsFramework::Server::Config]
    #
    attr_reader :config

    ##
    # Start the web server in the background. Does nothing if the web server
    # is already running.
    #
    # @return [self]
    #
    def start
      synchronize do
        unless running?
          @server = ::Puma::Server.new @app
          @server.min_threads = @config.min_threads
          @server.max_threads = @config.max_threads
          @server.leak_stack_on_error = @config.show_error_details?
          @server.binder.add_tcp_listener @config.bind_addr, @config.port
          @config.logger.info "FunctionsFramework: Serving function #{@function.name.inspect} " \
                              "on port #{@config.port}..."
          @server.run true
        end
      end
      self
    end

    ##
    # Stop the web server in the background. Does nothing if the web server
    # is not running.
    #
    # @param force [Boolean] Use a forced halt instead of a graceful shutdown
    # @param wait [Boolean] Block until shutdown is complete
    # @return [self]
    #
    def stop force: false, wait: false
      synchronize do
        if running?
          @config.logger.info "FunctionsFramework: Shutting down server..."
          if force
            @server.halt wait
          else
            @server.stop wait
          end
        end
      end
      self
    end

    ##
    # Wait for the server to stop. Returns immediately if the server is not
    # running.
    #
    # @param timeout [nil,Numeric] The timeout. If `nil` (the default), waits
    #     indefinitely, otherwise times out after the given number of seconds.
    # @return [self]
    #
    def wait_until_stopped timeout: nil
      @server&.thread&.join timeout
      self
    end

    ##
    # Determine if the web server is currently running
    #
    # @return [Boolean]
    #
    def running?
      @server&.thread&.alive?
    end

    ##
    # Cause this server to respond to SIGTERM, SIGINT, and SIGHUP by shutting
    # down gracefully.
    #
    # @return [self]
    #
    def respond_to_signals
      synchronize do
        return self if @signals_installed
        ::Signal.trap "SIGTERM" do
          Server.signal_enqueue "SIGTERM", @config.logger, @server
        end
        ::Signal.trap "SIGINT" do
          Server.signal_enqueue "SIGINT", @config.logger, @server
        end
        begin
          ::Signal.trap "SIGHUP" do
            Server.signal_enqueue "SIGHUP", @config.logger, @server
          end
        rescue ::ArgumentError
          # Not available on all systems
        end
        @signals_installed = true
      end
      self
    end

    class << self
      ## @private
      def start_signal_queue
        @signal_queue = ::Queue.new
        ::Thread.start do
          loop do
            signal, logger, server = @signal_queue.pop
            logger.info "FunctionsFramework: Caught #{signal}; shutting down server..."
            server&.stop
          end
        end
      end

      ## @private
      def signal_enqueue signal, logger, server
        @signal_queue << [signal, logger, server]
      end
    end

    start_signal_queue

    ##
    # The web server configuration. This object is yielded from the
    # {FunctionsFramework::Server} constructor and can be modified at that
    # point. Afterward, it is available from {FunctionsFramework::Server#config}
    # but it is frozen.
    #
    class Config
      ##
      # Create a new config object with the default settings
      #
      def initialize
        self.rack_env = nil
        self.bind_addr = nil
        self.port = nil
        self.min_threads = nil
        self.max_threads = nil
        self.show_error_details = nil
        self.logger = nil
      end

      ##
      # Set the Rack environment, or `nil` to use the default.
      # @param rack_env [String,nil]
      #
      def rack_env= rack_env
        @rack_env = rack_env || ::ENV["RACK_ENV"] ||
                    (::ENV["K_REVISION"] ? "production" : "development")
      end

      ##
      # Set the bind address, or `nil` to use the default.
      # @param bind_addr [String,nil]
      #
      def bind_addr= bind_addr
        @bind_addr = bind_addr || ::ENV["FUNCTION_BIND_ADDR"] || "0.0.0.0"
      end

      ##
      # Set the port number, or `nil` to use the default.
      # @param port [Integer,nil]
      #
      def port= port
        @port = (port || ::ENV["PORT"] || 8080).to_i
      end

      ##
      # Set the minimum number of worker threads, or `nil` to use the default.
      # @param min_threads [Integer,nil]
      #
      def min_threads= min_threads
        @min_threads = (min_threads || ::ENV["FUNCTION_MIN_THREADS"])&.to_i
      end

      ##
      # Set the maximum number of worker threads, or `nil` to use the default.
      # @param max_threads [Integer,nil]
      #
      def max_threads= max_threads
        @max_threads = (max_threads || ::ENV["FUNCTION_MAX_THREADS"])&.to_i
      end

      ##
      # Set whether to show detailed error messages, or `nil` to use the default.
      # @param show_error_details [Boolean,nil]
      #
      def show_error_details= show_error_details
        @show_error_details =
          if show_error_details.nil?
            !::ENV["FUNCTION_DETAILED_ERRORS"].to_s.empty?
          else
            show_error_details ? true : false
          end
      end

      ##
      # Set the logger for server messages, or `nil` to use the global default.
      # @param logger [Logger]
      #
      def logger= logger
        @logger = logger || ::FunctionsFramework.logger
      end

      ##
      # Returns the current Rack environment.
      # @return [String]
      #
      def rack_env
        @rack_env
      end

      ##
      # Returns the current bind address.
      # @return [String]
      #
      def bind_addr
        @bind_addr
      end

      ##
      # Returns the current port number.
      # @return [Integer]
      #
      def port
        @port
      end

      ##
      # Returns the minimum number of worker threads in the thread pool.
      # @return [Integer]
      #
      def min_threads
        @min_threads || 1
      end

      ##
      # Returns the maximum number of worker threads in the thread pool.
      # @return [Integer]
      #
      def max_threads
        @max_threads || 16
      end

      ##
      # Returns whether to show detailed error messages.
      # @return [Boolean]
      #
      def show_error_details?
        @show_error_details.nil? ? (@rack_env == "development") : @show_error_details
      end

      ##
      # Returns the logger.
      # @return [Logger]
      #
      def logger
        @logger
      end
    end

    ## @private
    class AppBase
      EXCLUDED_PATHS = ["/favicon.ico", "/robots.txt"].freeze

      def initialize config
        @config = config
      end

      def excluded_path? env
        path = env[::Rack::SCRIPT_NAME].to_s + env[::Rack::PATH_INFO].to_s
        EXCLUDED_PATHS.include? path
      end

      def interpret_response response
        case response
        when ::Array
          response
        when ::Rack::Response
          response.finish
        when ::String
          string_response response, 200
        when ::Hash
          string_response ::JSON.dump(response), 200, content_type: "application/json"
        when ::CloudEvents::CloudEventsError
          cloud_events_error_response response
        when ::StandardError
          message = "#{response.class}: #{response.message}"
          message = [message, *response.backtrace].join "\n\t"
          error_response message
        else
          error_response "Unexpected response type: #{response.class}"
        end
      end

      def notfound_response
        string_response "Not found", 404
      end

      def no_content_response
        [204, [], []]
      end

      def string_response string, status, content_type: nil
        string.force_encoding ::Encoding::ASCII_8BIT unless string.valid_encoding?
        if string.encoding == ::Encoding::ASCII_8BIT
          content_type ||= "application/octet-stream"
        else
          content_type ||= "text/plain"
          content_type = "#{content_type}; charset=#{string.encoding.name.downcase}"
        end
        headers = {
          "Content-Type"   => content_type,
          "Content-Length" => string.bytesize
        }
        [status, headers, [string]]
      end

      def cloud_events_error_response error
        @config.logger.warn error
        string_response "#{error.class}: #{error.message}", 400
      end

      def error_response message
        @config.logger.error message
        message = "Unexpected internal error" unless @config.show_error_details?
        string_response message, 500
      end

      def flush_streams
        $stdout.flush
        $stderr.flush
      end
    end

    ## @private
    class HttpApp < AppBase
      def initialize function, globals, config
        super config
        @function = function
        @globals = globals
      end

      def call env
        return notfound_response if excluded_path? env
        response =
          begin
            logger = env[::Rack::RACK_LOGGER] ||= @config.logger
            request = ::Rack::Request.new env
            logger.info "FunctionsFramework: Handling HTTP #{request.request_method} request"
            @function.call request, globals: @globals, logger: logger
          rescue ::StandardError => e
            e
          end
        interpret_response response
      ensure
        flush_streams
      end
    end

    ## @private
    class EventApp < AppBase
      def initialize function, globals, config
        super config
        @function = function
        @globals = globals
        @cloud_events = ::CloudEvents::HttpBinding.default
        @legacy_events = LegacyEventConverter.new
      end

      def call env
        return notfound_response if excluded_path? env
        return no_content_response if env[::Rack::REQUEST_METHOD] == "GET"
        logger = env[::Rack::RACK_LOGGER] ||= @config.logger
        event = decode_event env
        response =
          case event
          when ::CloudEvents::Event
            handle_cloud_event event, logger
          when ::Array
            ::CloudEvents::CloudEventsError.new "Batched CloudEvents are not supported"
          when ::CloudEvents::CloudEventsError
            event
          else
            raise "Unexpected event type: #{event.class}"
          end
        interpret_response response
      ensure
        flush_streams
      end

      private

      def decode_event env
        begin
          @cloud_events.decode_event env
        rescue ::CloudEvents::NotCloudEventError
          env[::Rack::RACK_INPUT].rewind rescue nil
          @legacy_events.decode_rack_env(env) || ::CloudEvents::CloudEventsError.new("Unrecognized event format")
        end
      rescue ::CloudEvents::CloudEventsError => e
        e
      end

      def handle_cloud_event event, logger
        logger.info "FunctionsFramework: Handling CloudEvent"
        @function.call event, globals: @globals, logger: logger
        "ok"
      rescue ::StandardError => e
        e
      end
    end
  end
end
