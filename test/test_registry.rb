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
    response = function.new_call.call "the-request"
    assert_equal "hello", response
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
    function.new_call.call "the-event"
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
    expected_rack_env = "google"
    tester = self
    task_completed = false
    registry.add_http "func1" do |_request|
      "hello"
    end
    function = registry["func1"]
    registry.add_startup_task do |func, config|
      tester.assert_same function, func
      tester.assert_equal expected_rack_env, config.rack_env
      task_completed = true
    end
    server = FunctionsFramework::Server.new function do |config|
      config.rack_env = expected_rack_env
    end
    registry.run_startup_tasks server
    assert task_completed
  end
end
