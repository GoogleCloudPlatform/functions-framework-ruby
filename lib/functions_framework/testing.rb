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

require "rack"

require "functions_framework"

module FunctionsFramework
  ##
  # Helpers for writing unit tests.
  #
  # Methods on this module can be called as module methods, or this module can
  # be included in a test class.
  #
  # ## Example
  #
  # Suppose we have the following app that uses the functions framework:
  #
  #     # app.rb
  #
  #     require "functions_framework"
  #
  #     FunctionsFramework.http "my-function" do |request|
  #       "Hello, world!"
  #     end
  #
  # The following is a test that could be run against that app:
  #
  #     # test_app.rb
  #
  #     require "minitest/autorun"
  #     require "functions_framework/testing"
  #
  #     class MyTest < Minitest::Test
  #       # Make the testing methods available.
  #       include FunctionsFramework::Testing
  #
  #       def test_my_function
  #         # Load app.rb and apply its functions within this block
  #         load_temporary "app.rb" do
  #           # Create a mock http (rack) request
  #           request = make_get_request "http://example.com"
  #
  #           # Call the function and get a rack response
  #           response = call_http "my-function", request
  #
  #           # Assert against the response
  #           assert_equal "Hello, world!", response.body.join
  #         end
  #       end
  #     end
  #
  module Testing
    ##
    # Load the given functions source for the duration of the given block,
    # and restore the previous status afterward.
    #
    # @param path [String] File path to load
    #
    def load_temporary path, &block
      path = ::File.expand_path path
      Testing.load_for_testing path, &block
    end

    ##
    # Run startup tasks for the given function name and return the initialized
    # globals hash.
    #
    # Normally, this will be run automatically prior to the first call to the
    # function using {call_http} or {call_event}, if it has not already been
    # run. However, you can call it explicitly to test its behavior. It cannot
    # be called more than once for any given function.
    #
    # By default, the {FunctionsFramework.logger} will be used, but you can
    # override that by providing your own logger. In particular, to disable
    # logging, you can pass `Logger.new(nil)`.
    #
    # @param name [String] The name of the function to start up.
    # @param logger [Logger] Use the given logger instead of the Functions
    #     Framework's global logger. Optional.
    # @param lenient [Boolean] If false (the default), raise an error if the
    #     given function has already had its startup tasks run. If true,
    #     duplicate requests to run startup tasks are ignored.
    # @return [Hash] The initialized globals.
    #
    def run_startup_tasks name, logger: nil, lenient: false
      function = Testing.current_registry[name]
      raise "Unknown function name #{name}" unless function
      globals = Testing.current_globals name
      if globals
        raise "Function #{name} has already been started up" unless lenient
      else
        globals = function.populate_globals
        Testing.current_registry.startup_tasks.each do |task|
          task.call function, globals: globals, logger: logger
        end
        Testing.current_globals name, globals
      end
      globals.freeze
    end

    ##
    # Call the given HTTP function for testing. The underlying function must
    # be of type `:http`. Returns the Rack response.
    #
    # By default, the startup tasks will be run for the given function if they
    # have not already been run. You can, however, disable running startup
    # tasks by providing an explicit globals hash.
    #
    # By default, the {FunctionsFramework.logger} will be used, but you can
    # override that by providing your own logger. In particular, to disable
    # logging, you can pass `Logger.new(nil)`.
    #
    # @param name [String] The name of the function to call
    # @param request [Rack::Request] The Rack request to send
    # @param globals [Hash] Do not run startup tasks, and instead provide the
    #     globals directly. Optional.
    # @param logger [Logger] Use the given logger instead of the Functions
    #     Framework's global logger. Optional.
    # @return [Rack::Response]
    #
    def call_http name, request, globals: nil, logger: nil
      globals ||= run_startup_tasks name, logger: logger, lenient: true
      function = Testing.current_registry[name]
      case function&.type
      when :http
        Testing.interpret_response do
          function.call request, globals: globals, logger: logger
        end
      when nil
        raise "Unknown function name #{name}"
      else
        raise "Function #{name} is not an HTTP function"
      end
    end

    ##
    # Call the given event function for testing. The underlying function must
    # be of type :cloud_event`.
    #
    # By default, the startup tasks will be run for the given function if they
    # have not already been run. You can, however, disable running startup
    # tasks by providing an explicit globals hash.
    #
    # By default, the {FunctionsFramework.logger} will be used, but you can
    # override that by providing your own logger. In particular, to disable
    # logging, you can pass `Logger.new(nil)`.
    #
    # @param name [String] The name of the function to call
    # @param event [::CloudEvents::Event] The event to send
    # @param globals [Hash] Do not run startup tasks, and instead provide the
    #     globals directly. Optional.
    # @param logger [Logger] Use the given logger instead of the Functions
    #     Framework's global logger. Optional.
    # @return [nil]
    #
    def call_event name, event, globals: nil, logger: nil
      globals ||= run_startup_tasks name, logger: logger, lenient: true
      function = Testing.current_registry[name]
      case function&.type
      when :cloud_event
        function.call event, globals: globals, logger: logger
        nil
      when nil
        raise "Unknown function name #{name}"
      else
        raise "Function #{name} is not a CloudEvent function"
      end
    end

    ##
    # Make a Rack request, for passing to a function test.
    #
    # @param url [URI,String] The URL to get, including query params.
    # @param method [String] The HTTP method (defaults to "GET").
    # @param body [String] The HTTP body, if any.
    # @param headers [Array,Hash] HTTP headers. May be given as a hash (of
    #     header names mapped to values), an array of strings (where each
    #     string is of the form `Header-Name: Header value`), or an array of
    #     two-element string arrays.
    # @return [Rack::Request]
    #
    def make_request url, method: ::Rack::GET, body: nil, headers: []
      env = Testing.build_standard_env URI(url), headers
      env[::Rack::REQUEST_METHOD] = method
      env[::Rack::RACK_INPUT] = ::StringIO.new body if body
      ::Rack::Request.new env
    end

    ##
    # Make a simple GET request, for passing to a function test.
    #
    # @param url [URI,String] The URL to get.
    # @param headers [Array,Hash] HTTP headers. May be given as a hash (of
    #     header names mapped to values), an array of strings (where each
    #     string is of the form `Header-Name: Header value`), or an array of
    #     two-element string arrays.
    # @return [Rack::Request]
    #
    def make_get_request url, headers = []
      make_request url, headers: headers
    end

    ##
    # Make a simple POST request, for passing to a function test.
    #
    # @param url [URI,String] The URL to post to.
    # @param body [String] The body to post.
    # @param headers [Array,Hash] HTTP headers. May be given as a hash (of
    #     header names mapped to values), an array of strings (where each
    #     string is of the form `Header-Name: Header value`), or an array of
    #     two-element string arrays.
    # @return [Rack::Request]
    #
    def make_post_request url, body, headers = []
      make_request url, method: ::Rack::POST, body: body, headers: headers
    end

    ##
    # Make a simple CloudEvent, for passing to a function test. The event data
    # is required, but all other parameters are optional (i.e. a reasonable or
    # random value will be generated if not provided).
    #
    # @param data [Object] The data
    # @param id [String] Event ID (optional)
    # @param source [String,URI] Event source (optional)
    # @param type [String] Event type (optional)
    # @param spec_version [String] Spec version (optional)
    # @param data_content_type [String,::CloudEvents::ContentType]
    #     Content type for the data (optional)
    # @param data_schema [String,URI] Data schema (optional)
    # @param subject [String] Subject (optional)
    # @param time [String,DateTime] Event timestamp (optional)
    # @return [::CloudEvents::Event]
    #
    def make_cloud_event data,
                         id: nil,
                         source: nil,
                         type: nil,
                         spec_version: nil,
                         data_content_type: nil,
                         data_schema: nil,
                         subject: nil,
                         time: nil
      id ||= "random-id-#{rand 100_000_000}"
      source ||= "functions-framework-testing"
      type ||= "com.example.test"
      spec_version ||= "1.0"
      ::CloudEvents::Event.new id:                id,
                               source:            source,
                               type:              type,
                               spec_version:      spec_version,
                               data_content_type: data_content_type,
                               data_schema:       data_schema,
                               subject:           subject,
                               time:              time,
                               data:              data
    end

    extend self

    @testing_registries = {}
    @main_globals = {}
    @mutex = ::Mutex.new

    class << self
      ## @private
      def load_for_testing path
        old_registry = ::FunctionsFramework.global_registry
        ::Thread.current[:functions_framework_testing_registry] =
          @mutex.synchronize do
            if @testing_registries.key? path
              ::FunctionsFramework.global_registry = @testing_registries[path]
            else
              new_registry = ::FunctionsFramework::Registry.new
              ::FunctionsFramework.global_registry = new_registry
              ::Kernel.load path
              @testing_registries[path] = new_registry
            end
          end
        ::Thread.current[:functions_framework_testing_globals] = {}
        yield
      ensure
        ::Thread.current[:functions_framework_testing_registry] = nil
        ::Thread.current[:functions_framework_testing_globals] = nil
        ::FunctionsFramework.global_registry = old_registry
      end

      ## @private
      def current_registry
        ::Thread.current[:functions_framework_testing_registry] ||
          ::FunctionsFramework.global_registry
      end

      ## @private
      def current_globals name, globals = nil
        name = name.to_s
        globals_by_name = ::Thread.current[:functions_framework_testing_globals] || @main_globals
        if globals
          globals_by_name[name] = globals
        else
          globals_by_name[name]
        end
      end

      ## @private
      def interpret_response
        response =
          begin
            yield
          rescue ::StandardError => e
            e
          end
        case response
        when ::Rack::Response
          response
        when ::Array
          ::Rack::Response.new response[2], response[0], response[1]
        when ::String
          string_response response, "text/plain", 200
        when ::Hash
          json = ::JSON.dump response
          string_response json, "application/json", 200
        when ::StandardError
          message = "#{response.class}: #{response.message}\n#{response.backtrace}\n"
          string_response message, "text/plain", 500
        else
          raise "Unexpected response type: #{response.inspect}"
        end
      end

      ## @private
      def string_response string, content_type, status
        headers = {
          "Content-Type"   => content_type,
          "Content-Length" => string.bytesize
        }
        ::Rack::Response.new string, status, headers
      end

      ## @private
      def build_standard_env url, headers
        env = {
          ::Rack::SCRIPT_NAME     => "",
          ::Rack::PATH_INFO       => url.path,
          ::Rack::QUERY_STRING    => url.query,
          ::Rack::SERVER_NAME     => url.host,
          ::Rack::SERVER_PORT     => url.port,
          ::Rack::RACK_URL_SCHEME => url.scheme,
          ::Rack::RACK_VERSION    => ::Rack::VERSION,
          ::Rack::RACK_LOGGER     => ::FunctionsFramework.logger,
          ::Rack::RACK_INPUT      => ::StringIO.new,
          ::Rack::RACK_ERRORS     => ::StringIO.new
        }
        headers.each do |header|
          case header
          when String
            name, value = header.split ":"
          when ::Array
            name, value = header
          end
          next unless name && value
          name = name.strip.upcase.tr "-", "_"
          name = "HTTP_#{name}" unless ["CONTENT_TYPE", "CONTENT_LENGTH"].include? name
          env[name] = value.strip
        end
        env
      end
    end
  end
end
