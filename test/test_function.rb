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
end
