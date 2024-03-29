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

describe FunctionsFramework::Registry do
  let(:registry) { FunctionsFramework::Registry.new }

  it "starts out empty" do
    assert_empty registry.names
    assert_nil registry["my_func"]
  end

  it "defines an http function" do
    tester = self
    registry.add_http "my_func" do |request|
      tester.assert_equal "the-request", request
      "hello"
    end
    assert_equal ["my_func"], registry.names
    function = registry["my_func"]
    assert_equal "my_func", function.name
    assert_equal :http, function.type
    response = function.call "the-request"
    assert_equal "hello", response
  end

  it "defines a typed function" do
    registry.add_typed "echo" do |event|
      return event
    end
    assert_equal ["echo"], registry.names
    function = registry["echo"]
    assert_equal "echo", function.name
    assert_equal :typed, function.type
  end

  it "defines a cloud_event function" do
    tester = self
    registry.add_cloud_event "my_func" do |event|
      tester.assert_equal "the-event", event
      "ok"
    end
    assert_equal ["my_func"], registry.names
    function = registry["my_func"]
    assert_equal "my_func", function.name
    assert_equal :cloud_event, function.type
    function.call "the-event"
  end

  it "defines multiple functions" do
    registry.add_http "func2" do |_request|
      "hello"
    end
    registry.add_cloud_event "func1" do |_event|
      "ok"
    end
    assert_equal ["func1", "func2"], registry.names
    assert_equal :cloud_event, registry["func1"].type
    assert_equal :http, registry["func2"].type
  end

  it "defines startup tasks" do
    tester = self
    task_completed = false
    registry.add_http "func1" do |_request|
      "hello"
    end
    function = registry["func1"]
    registry.add_startup_task do |func|
      tester.assert_same function, func
      task_completed = true
      set_global :foo, :bar
    end
    tasks = registry.startup_tasks
    assert_equal 1, tasks.size
    task = tasks.first
    assert_equal :startup_task, task.type
    globals = {}
    task.call function, globals: globals
    assert task_completed
    assert_equal :bar, globals[:foo]
  end

  it "defines a function without a formal parameter" do
    registry.add_http "my_func" do
      "hello"
    end
    response = registry["my_func"].call "the-request"
    assert_equal "hello", response
  end
end
