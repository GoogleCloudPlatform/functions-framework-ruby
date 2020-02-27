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
    def load_temporary path
      registry = ::FunctionsFramework::Registry.new
      old_registry = ::FunctionsFramework.global_registry
      ::FunctionsFramework.global_registry = registry
      begin
        ::Kernel.load path
        yield
      ensure
        ::FunctionsFramework.global_registry = old_registry
      end
    end

    ##
    # Call the given HTTP function for testing. The underlying function must
    # be of type `:http`.
    #
    # @param name [String] The name of the function to call
    # @param request [Rack::Request] The Rack request to send
    # @return [Rack::Response]
    #
    def call_http name, request
      function = ::FunctionsFramework.global_registry[name]
      case function&.type
      when :http
        Testing.interpret_response { function.call request }
      when nil
        raise "Unknown function name #{name}"
      else
        raise "Function #{name} is not an HTTP function"
      end
    end

    ##
    # Call the given event function for testing. The underlying function must
    # be of type `:event` or `:cloud_event`.
    #
    # @param name [String] The name of the function to call
    # @param event [FunctionsFramework::CloudEvets::Event] The event to send
    # @return [nil]
    #
    def call_event name, event
      function = ::FunctionsFramework.global_registry[name]
      case function&.type
      when :event, :cloud_event
        function.call event
        nil
      when nil
        raise "Unknown function name #{name}"
      else
        raise "Function #{name} is not a CloudEvent function"
      end
    end

    ##
    # Make a simple GET request, for passing to a function test.
    #
    # @param url [URI,String] The URL to get.
    # @return [Rack::Request]
    #
    def make_get_request url, headers = []
      env = Testing.build_standard_env URI(url), headers
      env[::Rack::REQUEST_METHOD] = ::Rack::GET
      ::Rack::Request.new env
    end

    ##
    # Make a simple POST request, for passing to a function test.
    #
    # @param url [URI,String] The URL to post to.
    # @param data [String] The body to post.
    # @return [Rack::Request]
    #
    def make_post_request url, data, headers = []
      env = Testing.build_standard_env URI(url), headers
      env[::Rack::REQUEST_METHOD] = ::Rack::POST
      env[::Rack::RACK_INPUT] = ::StringIO.new data
      ::Rack::Request.new env
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
    # @param data_content_type [String,FunctionsFramework::CloudEvents::ContentType]
    #     Content type for the data (optional)
    # @param data_schema [String,URI] Data schema (optional)
    # @param subject [String] Subject (optional)
    # @param time [String,DateTime] Event timestamp (optional)
    # @return [FunctionsFramework::CloudEvents::Event]
    #
    def make_cloud_event data,
                         id: nil, source: nil, type: nil, spec_version: nil,
                         data_content_type: nil, data_schema: nil, subject: nil, time: nil
      id ||= "random-id-#{rand 100_000_000}"
      source ||= "functions-framework-testing"
      type ||= "com.example.test"
      spec_version ||= "1.0"
      CloudEvents::Event.new id: id, source: source, type: type, spec_version: spec_version,
                             data_content_type: data_content_type, data_schema: data_schema,
                             subject: subject, time: time, data: data
    end

    extend self

    class << self
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
          name, value = header.split ":"
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
