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
  it "represents an http function" do
    function = FunctionsFramework::Function.new "my_func", :http do |request|
      assert_equal "the-request", request
      "hello"
    end
    assert_equal "my_func", function.name
    assert_equal :http, function.type
    response = function.call "the-request"
    assert_equal "hello", response
  end

  it "represents an http function with a return statement" do
    function = FunctionsFramework::Function.new "my_func", :http do |request|
      return "hello" if request == "the-request"
      "goodbye"
    end
    assert_equal "my_func", function.name
    assert_equal :http, function.type
    response = function.call "the-request"
    assert_equal "hello", response
  end

  it "defines an event function" do
    function = FunctionsFramework::Function.new "my_func", :event do |data, context|
      assert_equal "the-data", data
      assert_equal "the-id", context.id
      "ok"
    end
    assert_equal "my_func", function.name
    assert_equal :event, function.type
    event = OpenStruct.new data: "the-data", id: "the-id"
    function.call event
  end

  it "defines a cloud_event function" do
    function = FunctionsFramework::Function.new "my_func", :cloud_event do |event|
      assert_equal "the-event", event
      "ok"
    end
    assert_equal "my_func", function.name
    assert_equal :cloud_event, function.type
    function.call "the-event"
  end
end
