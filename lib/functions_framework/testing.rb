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

require "functions_framework"

module FunctionsFramework
  ##
  # Testing helpers
  #
  module Testing
    class << self
      ##
      # Call the given HTTP function for testing. The underlying function must
      # be of type `:http`.
      #
      # @param name [String] The name of the function to call
      # @param request [Rack::Request] The Rack request to send
      # @return [Rack::Response]
      #
      def call_http name, request
        function = FunctionsFramework.global_registry[name]
        case function&.type
        when :http
          interpret_response { function.call request }
        when nil
          raise "Unknown function name #{name}"
        else
          raise "Function #{name} is not an HTTP function"
        end
      end

      ##
      # Call the given event function for testing. The underlying function can
      # be of type `:event` or `:cloud_event`.
      #
      # @param name [String] The name of the function to call
      # @param event [FunctionsFramework::CloudEvets::Event] The event to send
      # @return [nil]
      #
      def call_event name, event
        function = FunctionsFramework.global_registry[name]
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

      private

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

      def string_response string, content_type, status
        headers = {
          "Content-Type"   => content_type,
          "Content-Length" => string.bytesize
        }
        ::Rack::Response.new string, status, headers
      end
    end
  end
end
