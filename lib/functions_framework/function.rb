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
  # A function has a name, a type, and an implementation.
  #
  # The implementation in general is an object that responds to the `call`
  # method. For a function of type `:http`, the `call` method takes a single
  # `Rack::Request` argument and returns one of various HTTP response types.
  # See {FunctionsFramework::Registry.add_http}. For a function of type
  # `:cloud_event`, the `call` method takes a single
  # [CloudEvent](https://rubydoc.info/gems/cloud_events/CloudEvents/Event)
  # argument, and does not return a value.
  # See {FunctionsFramework::Registry.add_cloud_event}.
  #
  # If a callable object is provided directly, its `call` method is invoked for
  # every function execution. Note that this means it may be called multiple
  # times concurrently in separate threads.
  #
  # Alternately, the implementation may be provided as a class that should be
  # instantiated to produce a callable object. If a class is provided, it should
  # either subclass {FunctionsFramework::Function::CallBase} or respond to the
  # same constructor interface, i.e. accepting arbitrary keyword arguments. A
  # separate callable object will be instantiated from this class for every
  # function invocation, so each instance will be used for only one invocation.
  #
  # Finally, an implementation can be provided as a block. If a block is
  # provided, it will be recast as a `call` method in an anonymous subclass of
  # {FunctionsFramework::Function::CallBase}. Thus, providing a block is really
  # just syntactic sugar for providing a class. (This means, for example, that
  # the `return` keyword will work within the block because it is treated as a
  # method.)
  #
  class Function
    ##
    # Create a new function definition.
    #
    # @param name [String] The function name
    # @param type [Symbol] The type of function. Valid types are `:http` and
    #     `:cloud_event`.
    # @param callable [Class,#call] A callable object or class.
    # @param block [Proc] The function code as a block.
    #
    def initialize name, type, callable = nil, &block
      @name = name
      @type = type
      @callable = @callable_class = nil
      if callable.respond_to? :call
        @callable = callable
      elsif callable.is_a? ::Class
        @callable_class = callable
      elsif block_given?
        @callable_class = ::Class.new CallBase do
          define_method :call, &block
        end
      else
        raise ::ArgumentError, "No callable given for function"
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
    # Get a callable for performing a function invocation. This will either
    # return the singleton callable object, or instantiate a new callable from
    # the configured class.
    #
    # @param logger [::Logger] The logger for use by function executions. This
    #     may or may not be used by the callable.
    # @return [#call]
    #
    def new_call logger: nil
      return @callable unless @callable.nil?
      logger ||= FunctionsFramework.logger
      @callable_class.new logger: logger, function_name: name, function_type: type
    end

    ##
    # A base class for a callable object that provides calling context.
    #
    # An object of this class is `self` while a function block is running.
    #
    class CallBase
      ##
      # Create a callable object with the given context.
      #
      # @param context [keywords] A set of context arguments. See {#context} for
      #     a list of keys that will generally be passed in. However,
      #     implementations should be prepared to accept any abritrary keys.
      #
      def initialize **context
        @context = context
      end

      ##
      # A keyed hash of context information. Common context keys include:
      #
      #  *  **:logger** (`Logger`) A logger for use by this function call.
      #  *  **:function_name** (`String`) The name of the running function.
      #  *  **:function_type** (`Symbol`) The type of the running function,
      #     either `:http` or `:cloud_event`.
      #
      # @return [Hash]
      #
      attr_reader :context
    end
  end
end
