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

require "functions_framework/cloud_events"
require "functions_framework/function"
require "functions_framework/registry"
require "functions_framework/version"

##
# The Functions Framework for Ruby
#
module FunctionsFramework
  @global_registry = Registry.new

  ##
  # The default target function name
  # @return [String]
  #
  DEFAULT_TARGET = "function".freeze

  class << self
    ##
    # The "global" registry that holds events defined by the
    # {FunctionsFramework} class methods.
    #
    # @return [FunctionsFramework::Registry]
    #
    attr_reader :global_registry

    ##
    # Define an HTTP function.
    #
    # You must provide a name for the function, and a block that implemets the
    # function. The block should take a single `Rack::Request` argument. It
    # should return one of the following:
    #  *  A standard 3-element Rack response array. See
    #     https://github.com/rack/rack/blob/master/SPEC
    #  *  A `Rack::Response` object.
    #  *  A simple String that will be sent as the response body.
    #  *  A Hash object that will be encoded as JSON and sent as the response
    #     body.
    #
    # @param name [String] The function name. Defaults to {DEFAULT_TARGET}.
    # @param block [Proc] The function code as a proc.
    # @return [self]
    #
    def http name = DEFAULT_TARGET, &block
      global_registry.add_http name, &block
      self
    end

    ##
    # Define a CloudEvent function.
    #
    # You must provide a name for the function, and a block that implemets the
    # function. The block should take two arguments: the event _data_ and the
    # event _context_. Any return value is ignored.
    #
    # The event data argument will be one of the following types:
    #  *  A `String` (with encoding `ASCII-8BIT`) if the data is in the form of
    #     binary data. You may choose to perform additional interpretation of
    #     the binary data using information in the content type provided by the
    #     context argument.
    #  *  Any data type that can be represented in JSON (i.e. `String`,
    #     `Integer`, `Array`, `Hash`, `true`, `false`, or `nil`) if the event
    #     came with a JSON payload. The content type may also be set in the
    #     context if the data is a String.
    #
    # The context argument will be of type {FunctionsFramework::CloudEvents::Event},
    # and will contain CloudEvents context attributes such as `id` and `type`.
    #
    # See also {FunctionsFramework.cloud_event} which defines a function that
    # takes a single argument of type {FunctionsFramework::CloudEvents::Event}.
    #
    # @param name [String] The function name. Defaults to {DEFAULT_TARGET}.
    # @param block [Proc] The function code as a proc.
    # @return [self]
    #
    def event name = DEFAULT_TARGET, &block
      global_registry.add_event name, &block
      self
    end

    ##
    # Define a CloudEvent function.
    #
    # You must provide a name for the function, and a block that implemets the
    # function. The block should take _one_ argument: the event object of type
    # {FunctionsFramework::CloudEvents::Event}. Any return value is ignored.
    #
    # See also {FunctionsFramework.event} which creates a function that takes
    # data and context as separate arguments.
    #
    # @param name [String] The function name. Defaults to {DEFAULT_TARGET}.
    # @param block [Proc] The function code as a proc.
    # @return [self]
    #
    def cloud_event name = DEFAULT_TARGET, &block
      global_registry.add_cloud_event name, &block
      self
    end

    ##
    # Start the functions framework server in the background.
    #
    # @param target [String] The name of the function to run
    # @yield [FunctionsFramework::Server::Config] A config object that can be
    #     manipulated to configure the server.
    # @return [FunctionsFramework::Server]
    #
    def start target, &block
      require "functions_framework/server"
      function = global_registry[target]
      raise ::ArgumentError, "Undefined function: #{target}" if function.nil?
      server = Server.new function, &block
      server.respond_to_signals
      server.start
    end

    ##
    # Run the functions framework server and block until it stops.
    #
    # @param target [String] The name of the function to run
    # @yield [FunctionsFramework::Server::Config] A config object that can be
    #     manipulated to configure the server.
    # @return [self]
    #
    def run target, &block
      server = start target, &block
      server.wait_until_stopped
      self
    end
  end
end
