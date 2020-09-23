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
  # ## Function implementations
  #
  # The implementation in general is an object that responds to the `call`
  # method.
  #
  #  *  For a function of type `:http`, the `call` method takes a single
  #     `Rack::Request` argument and returns one of various HTTP response
  #     types. See {FunctionsFramework::Registry.add_http}.
  #  *  For a function of type `:cloud_event`, the `call` method takes a single
  #     [CloudEvent](https://cloudevents.github.io/sdk-ruby/latest/CloudEvents/Event)
  #     argument, and does not return a value. See
  #     {FunctionsFramework::Registry.add_cloud_event}.
  #  *  For a function of type `:startup_task`, the `call` method takes a
  #     single {FunctionsFramework::Function} argument, and does not return a
  #     value. See {FunctionsFramework::Registry.add_startup_task}.
  #
  # The implementation can be specified in one of three ways:
  #
  #  *  A callable object can be passed in the `callable` keyword argument. The
  #     object's `call` method will be invoked for every function execution.
  #     Note that this means it may be called multiple times concurrently in
  #     separate threads.
  #  *  A callable _class_ can be passed in the `callable` keyword argument.
  #     This class should subclass {FunctionsFramework::Function::Callable} and
  #     define the `call` method. A separate instance of this class will be
  #     created for each function invocation.
  #  *  A block can be provided. It will be used to define the `call` method in
  #     an anonymous subclass of {FunctionsFramework::Function::Callable}.
  #     Thus, providing a block is really just syntactic sugar for providing a
  #     class. (This means, for example, that the `return` keyword will work
  #     as expected within the block because it is treated as a method.)
  #
  # When the implementation is provided as a callable class or block, it is
  # executed in the context of a {FunctionsFramework::Function::Callable}
  # object. This object provides a convenience accessor for the Logger, and
  # access to _globals_, which are data defined by the application startup
  # process and available to each function invocation. Typically, globals are
  # used for shared global resources such as service connections and clients.
  #
  class Function
    ##
    # Create a new HTTP function definition.
    #
    # @param name [String] The function name
    # @param callable [Class,#call] A callable object or class.
    # @param block [Proc] The function code as a block.
    # @return [FunctionsFramework::Function]
    #
    def self.http name, callable = nil, &block
      new name, :http, callable, &block
    end

    ##
    # Create a new CloudEvents function definition.
    #
    # @param name [String] The function name
    # @param callable [Class,#call] A callable object or class.
    # @param block [Proc] The function code as a block.
    # @return [FunctionsFramework::Function]
    #
    def self.cloud_event name, callable = nil, &block
      new name, :cloud_event, callable, &block
    end

    ##
    # Create a new startup task function definition.
    #
    # @param callable [Class,#call] A callable object or class.
    # @param block [Proc] The function code as a block.
    # @return [FunctionsFramework::Function]
    #
    def self.startup_task callable = nil, &block
      new nil, :startup_task, callable, &block
    end

    ##
    # Create a new function definition.
    #
    # @param name [String] The function name
    # @param type [Symbol] The type of function. Valid types are `:http`,
    #     `:cloud_event`, and `:startup_task`.
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
        @callable_class = ::Class.new Callable do
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
    # Populate the given globals hash with this function's info.
    #
    # @param globals [Hash] Initial globals hash (optional).
    # @return [Hash] A new globals hash with this function's info included.
    #
    def populate_globals globals = nil
      result = { function_name: name, function_type: type }
      result.merge! globals if globals
      result
    end

    ##
    # Get a callable for performing a function invocation. This will either
    # return the singleton callable object, or instantiate a new callable from
    # the configured class.
    #
    # @param logger [::Logger] The logger for use by function executions. This
    #     may or may not be used by the callable.
    # @return [#call]
    #
    def call *args, globals: nil, logger: nil
      callable = @callable || @callable_class.new(globals: globals, logger: logger)
      callable.call(*args)
    end

    ##
    # A base class for a callable object that provides calling context.
    #
    # An object of this class is `self` while a function block is running.
    #
    class Callable
      ##
      # Create a callable object with the given context.
      #
      # @param globals [Hash] A set of globals available to the call.
      # @param logger [Logger] A logger for use by the function call.
      #
      def initialize globals: nil, logger: nil
        @__globals = globals || {}
        @__logger = logger || FunctionsFramework.logger
      end

      ##
      # Get the given named global.
      #
      # For most function calls, the following globals will be defined:
      #
      #  *  **:function_name** (`String`) The name of the running function.
      #  *  **:function_type** (`Symbol`) The type of the running function,
      #     either `:http` or `:cloud_event`.
      #
      # You can also set additional globals from a startup task.
      #
      # @param key [Symbol,String] The name of the global to get.
      # @return [Object]
      #
      def global key
        @__globals[key]
      end

      ##
      # Set a global. This can be called from startup tasks, but the globals
      # are frozen when the server starts, so this call will raise an exception
      # if called from a normal function.
      #
      # @param key [Symbol,String]
      # @param value [Object]
      #
      def set_global key, value
        @__globals[key] = value
      end

      ##
      # A logger for use by this call.
      #
      # @return [Logger]
      #
      def logger
        @__logger
      end
    end
  end
end
