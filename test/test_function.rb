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

require "helper"
require "ostruct"

describe FunctionsFramework::Function do
  it "represents an http function using a block" do
    tester = self
    function = FunctionsFramework::Function.http "my_func" do |request|
      tester.assert_equal "the-request", request
      tester.assert_equal "my_func", global(:function_name)
      "hello"
    end
    assert_equal "my_func", function.name
    assert_equal :http, function.type
    response = function.call "the-request", globals: { function_name: function.name }
    assert_equal "hello", response
  end

  it "represents an http function using a block with a return statement" do
    function = FunctionsFramework::Function.http "my_func" do |request|
      return "hello" if request == "the-request"
      "goodbye"
    end
    assert_equal "my_func", function.name
    assert_equal :http, function.type
    response = function.call "the-request"
    assert_equal "hello", response
  end

  it "defines a cloud_event function using a block" do
    tester = self
    function = FunctionsFramework::Function.cloud_event "my_event_func" do |event|
      tester.assert_equal "the-event", event
      tester.assert_equal "my_event_func", global(:function_name)
      "ok"
    end
    assert_equal "my_event_func", function.name
    assert_equal :cloud_event, function.type
    function.call "the-event", globals: { function_name: function.name }
  end

  it "defines a startup function using a block" do
    tester = self
    function = FunctionsFramework::Function.startup_task do |func|
      tester.assert_equal "the-function", func
      tester.assert_nil global(:function_name)
    end
    assert_nil function.name
    assert_equal :startup_task, function.type
    function.call "the-function", globals: { function_name: function.name }
  end

  it "represents an http function using an object" do
    callable = proc do |request|
      assert_equal "the-request", request
      "hello"
    end
    function = FunctionsFramework::Function.http "my_func", callable: callable
    assert_equal "my_func", function.name
    assert_equal :http, function.type
    response = function.call "the-request"
    assert_equal "hello", response
  end

  it "represents an http function using a class" do
    class MyCallable
      def initialize **_keywords
      end

      def call request
        request == "the-request" ? "hello" : "whoops"
      end
    end

    function = FunctionsFramework::Function.http "my_func", callable: MyCallable
    assert_equal "my_func", function.name
    assert_equal :http, function.type
    response = function.call "the-request"
    assert_equal "hello", response
  end

  it "can call a startup function with no formal argument" do
    tester = self
    function = FunctionsFramework::Function.startup_task do
      tester.assert_nil global(:function_name)
    end
    function.call "the-function", globals: { function_name: function.name }
  end

  it "sets a global from a startup task" do
    tester = self
    startup = FunctionsFramework::Function.startup_task do
      set_global :foo, :bar
    end
    function = FunctionsFramework::Function.http "my_func" do |_request|
      tester.assert_equal :bar, global(:foo)
      "hello"
    end
    globals = {}
    startup.call "the-startup", globals: globals
    function.call "the-function", globals: globals
  end

  it "sets a lazy global from a startup task" do
    tester = self
    counter = 0
    startup = FunctionsFramework::Function.startup_task do
      set_global :foo do
        counter += 1
        :bar
      end
    end
    function = FunctionsFramework::Function.http "my_func" do |_request|
      tester.assert_equal :bar, global(:foo)
      "hello"
    end
    globals = {}
    startup.call "the-startup", globals: globals
    assert_equal 0, counter
    function.call "the-function", globals: globals
    assert_equal 1, counter
    function.call "the-function", globals: globals
    assert_equal 1, counter
  end

  it "allows a global of type Minitest::Mock" do
    startup = FunctionsFramework::Function.startup_task do
      set_global :foo, Minitest::Mock.new
    end
    function = FunctionsFramework::Function.http "my_func" do |_request|
      global :foo
      "hello"
    end
    globals = {}
    startup.call "the-startup", globals: globals
    function.call "the-function", globals: globals
  end

  describe "typed" do
    # Ruby class representing a single integer value encoded as a JSON int
    class IntValue
      def initialize val
        @value = val
      end

      def self.decode_json json
        IntValue.new json.to_i
      end

      def to_json(*_args)
        get.to_s
      end

      def get
        @value
      end
    end

    # class_func provides a function as a class that implements the Callable
    # interface.
    class_func = ::Class.new FunctionsFramework::Function::Callable do
      define_method :call do |_request|
        global :function_name
      end
    end

    it "can be defined with no custom type" do
      function = FunctionsFramework::Function.typed "int_adder" do |request|
        request + 1
      end
      assert_equal "int_adder", function.name
      assert_equal :typed, function.type

      res = function.call 1, globals: {}

      assert_equal 2, res
    end

    it "can be defined using a block and custom_type" do
      function = FunctionsFramework::Function.typed "int_adder", request_class: IntValue do |request|
        IntValue.new request.get + 1
      end
      assert_equal "int_adder", function.name
      assert_equal :typed, function.type

      res = function.call (IntValue.new 1), globals: {}

      assert_equal 2, res.get
    end

    it "can be defined using a callable class" do
      function = FunctionsFramework::Function.typed "using_callable_class", callable: class_func
      assert_equal "using_callable_class", function.name
      assert_equal :typed, function.type
      globals = function.populate_globals

      res = function.call nil, globals: globals

      assert_equal function.name, res
    end

    it "can be defined using an instance of a callable" do
      callable_class = class_func.new globals: { function_name: "fake_global_name" }
      function = FunctionsFramework::Function.typed "using_callable", callable: callable_class
      assert_equal "using_callable", function.name
      assert_equal :typed, function.type
      globals = function.populate_globals

      res = function.call nil, globals: globals

      assert_equal "fake_global_name", res
    end

    it "function can access globals" do
      function = FunctionsFramework::Function.typed "printName" do |_request|
        global :function_name
      end
      globals = function.populate_globals

      res = function.call nil, globals: globals

      assert_equal function.name, res
    end

    it "function rejects request_class that does not implement decode_json" do
      assert_raises ::ArgumentError do
        FunctionsFramework::Function.typed "bad_fn", request_class: ::Class
      end
    end
  end
end
