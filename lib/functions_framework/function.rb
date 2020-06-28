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

module FunctionsFramework
  ##
  # Representation of a function.
  #
  # A function has a name, a type, and a code definition.
  #
  class Function
    ##
    # Create a new function definition.
    #
    # @param name [String] The function name
    # @param type [Symbol] The type of function. Valid types are `:http` and
    #     `:cloud_event`.
    # @param block [Proc] The function code as a proc
    #
    def initialize name, type, &block
      @name = name
      @type = type
      @execution_context_class = Class.new ExecutionContext do
        define_method :call, &block
      end
    end

    ##
    # @return [String] The function name
    #
    attr_reader :name

    ##
    # @return [Symbol] The function type
    #
    attr_reader :type

    ##
    # Create an execution context.
    #
    # The returned execution context has a `#call` method that can be invoked
    # to call the function. You must pass an argument to `#call` appropriate to
    # the type of function:
    #
    #  *  A `:http` type function takes a `Rack::Request` argument, and returns
    #     a Rack response type. See {FunctionsFramework::Registry.add_http}.
    #  *  A `:cloud_event` type function takes a
    #     {FunctionsFramework::CloudEvents::Event} argument, and does not
    #     return a value. See {FunctionsFramework::Registry.add_cloud_event}.
    #
    # @param logger [::Logger] The logger for use by function executions.
    # @return [FunctionsFramework::ExecutionContext]
    #
    def execution_context logger: nil
      @execution_context_class.new self, logger: logger
    end
  end
end
