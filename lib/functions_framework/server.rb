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
  # Web server
  #
  class Server
    include ::MonitorMixin

    ##
    # Create a new web server
    #
    # @param function [FunctionsFramework::Function]
    #     The function to execute.
    # @yield [FunctionsFramework::Server::Config] A config object that can be
    #     manipulated to configure this server.
    #
    def initialize function
      super()
      @config = Config.new
      yield @config if block_given?
      @config.freeze
      @app =
        case function.type
        when :http
          HttpApp.new function, @config
        when :event, :cloud_event
          EventApp.new function, @config
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
    # The final configuration.
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
          @server.leak_stack_on_error = @config.show_verbose_errors?
          @server.binder.add_tcp_listener @config.bind_addr, @config.port
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
    # @return [self]
    #
    def stop force: false
      synchronize do
        if running?
          if force
            @server.halt
          else
            @server.stop
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
      synchronize do
        @server.thread.join timeout if running?
      end
      self
    end

    ##
    # Determine if the web server is currently running
    #
    # @return [Boolean]
    #
    def running?
      synchronize do
        @server&.thread&.alive?
      end
    end

    ##
    # Cause this server to respond to SIGTERM, SIGINT, and SIGHUP by shutting
    # down gracefully.
    #
    # @return [Boolean]
    #
    def respond_to_signals
      synchronize do
        unless @signals_installed
          ::Signal.trap "SIGTERM" do
            @server&.stop true
          end
          ::Signal.trap "SIGINT" do
            @server&.stop false
          end
          ::Signal.trap "SIGHUP" do
            @server&.stop false
          end
          @signals_installed = true
        end
      end
      self
    end

    ##
    # The web server configuration
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
        self.show_verbose_errors = nil
      end

      ##
      # Set the Rack environment, or `nil` to use the default.
      # @param rack_env [String,nil]
      #
      def rack_env= rack_env
        @rack_env = rack_env || ::ENV["RACK_ENV"] || "development"
      end

      ##
      # Set the bind address, or `nil` to use the default.
      # @param bind_addr [String,nil]
      #
      def bind_addr= bind_addr
        @bind_addr = bind_addr || ::ENV["BIND_ADDR"]
      end

      ##
      # Set the port number, or `nil` to use the default.
      # @param port [Integer,nil]
      #
      def port= port
        @port = (port || ::ENV["PORT"])&.to_i
      end

      ##
      # Set the minimum number of worker threads, or `nil` to use the default.
      # @param min_threads [Integer,nil]
      #
      def min_threads= min_threads
        @min_threads = (min_threads || ::ENV["MIN_THREADS"])&.to_i
      end

      ##
      # Set the maximum number of worker threads, or `nil` to use the default.
      # @param max_threads [Integer,nil]
      #
      def max_threads= max_threads
        @max_threads = (max_threads || ::ENV["MAX_THREADS"])&.to_i
      end

      ##
      # Set whether to show verbose error messages, or `nil` to use the default.
      # @param show_verbose_errors [Boolean,nil]
      #
      def show_verbose_errors= show_verbose_errors
        @show_verbose_errors =
          if show_verbose_errors.nil?
            nil
          else
            show_verbose_errors ? true : false
          end
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
        @bind_addr || (@rack_env == "development" ? "127.0.0.1" : "0.0.0.0")
      end

      ##
      # Returns the current port number.
      # @return [Integer]
      #
      def port
        @port || 8080
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
        @max_threads || (@rack_env == "development" ? 1 : 16)
      end

      ##
      # Returns whether to show verbose error messages.
      # @return [Boolean]
      #
      def show_verbose_errors?
        @show_verbose_errors.nil? ? (@rack_env == "development") : @show_verbose_errors
      end
    end

    ## @private
    class AppBase
      def initialize config
        @config = config
      end

      def interpret_response response
        case response
        when ::Array
          response
        when ::Rack::Response
          response.finish
        when ::String
          string_response response, "text/plain", 200
        when ::Hash
          json = ::JSON.dump response
          string_response json, "application/json", 200
        when ::StandardError
          error = error_message response
          string_response error, "text/plain", 500
        else
          e = ::StandardError.new "Unexpected response type: #{response.class}"
          error = error_message e
          string_response error, "text/plain", 500
        end
      end

      def string_response string, content_type, status
        headers = {
          "Content-Type"   => content_type,
          "Content-Length" => string.bytesize
        }
        [status, headers, [string]]
      end

      def error_message error
        if @config.show_verbose_errors?
          "#{error.class}: #{error.message}\n#{error.backtrace}\n"
        else
          "Unexpected internal error"
        end
      end
    end

    ## @private
    class HttpApp < AppBase
      def initialize function, config
        super config
        @function = function
      end

      def call env
        request = ::Rack::Request.new env
        response =
          begin
            @function.call request
          rescue ::StandardError => e
            warn "#{e.class}: #{e.message}\n#{e.backtrace}\n"
            e
          end
        interpret_response response
      end
    end

    ## @private
    class EventApp < AppBase
      def initialize function, config
        super config
        @function = function
      end

      def call env
        event = CloudEvents.decode_rack_env env
        response =
          begin
            @function.call event
            "ok"
          rescue ::StandardError => e
            warn "#{e.class}: #{e.message}\n#{e.backtrace}\n"
            e
          end
        interpret_response response
      end
    end
  end
end
