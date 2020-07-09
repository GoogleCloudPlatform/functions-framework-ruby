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

require "monitor"

module FunctionsFramework
  ##
  # Registry providing lookup of functions by name.
  #
  class Registry
    include ::MonitorMixin

    ##
    # Create a new empty registry.
    #
    def initialize
      super()
      @functions = {}
    end

    ##
    # Look up a function definition by name.
    #
    # @param name [String] The function name
    # @return [FunctionsFramework::Function] if the function is found
    # @return [nil] if the function is not found
    #
    def [] name
      @functions[name.to_s]
    end

    ##
    # Returns the list of defined names
    #
    # @return [Array<String>]
    #
    def names
      @functions.keys.sort
    end

    ##
    # Add an HTTP function to the registry.
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
    # @param name [String] The function name
    # @param block [Proc] The function code as a proc
    # @return [self]
    #
    def add_http name, &block
      name = name.to_s
      synchronize do
        raise ::ArgumentError, "Function already defined: #{name}" if @functions.key? name
        @functions[name] = Function.new name, :http, &block
      end
      self
    end

    ##
    # Add a CloudEvent function to the registry.
    #
    # You must provide a name for the function, and a block that implemets the
    # function. The block should take _one_ argument: the event object of type
    # [`CloudEvents::Event`](https://rubydoc.info/gems/cloud_events/CloudEvents/Event).
    # Any return value is ignored.
    #
    # @param name [String] The function name
    # @param block [Proc] The function code as a proc
    # @return [self]
    #
    def add_cloud_event name, &block
      name = name.to_s
      synchronize do
        raise ::ArgumentError, "Function already defined: #{name}" if @functions.key? name
        @functions[name] = Function.new name, :cloud_event, &block
      end
      self
    end
  end
end
