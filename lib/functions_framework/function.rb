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
  # Representation of a function
  #
  class Function
    ##
    # Create a new function definition
    #
    # @param name [String] The function name
    # @param type [Symbol] The type of function. Valid types are
    #     `:http`, `:event`, and `:cloud_event`.
    # @param block [Proc] The function code as a proc
    #
    def initialize name, type, &block
      @name = name
      @type = type
      @block = block
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
    # @return [Proc] The function code as a proc
    #
    attr_reader :block

    ##
    # Call the function. You must pass an argument appropriate to the type
    # of function.
    #
    #  *  A `:http` type function takes a `Rack::Request` argument, and returns
    #     a Rack response type. See {FunctionsFramework::Registry.add_http}.
    #  *  A `:event` or `:cloud_event` type function takes a
    #     {FunctionsFramework::CloudEvents::Event} argument, and does not
    #     return a value. See {FunctionsFramework::Registry.add_cloud_event}.
    #     Note that for an `:event` type function, the passed event argument is
    #     split into two arguments when passed to the underlying block.
    #
    # @param argument [Object]
    # @return [Object]
    #
    def call argument
      case type
      when :event
        block.call argument.data, argument
      else
        block.call argument
      end
    end
  end
end
