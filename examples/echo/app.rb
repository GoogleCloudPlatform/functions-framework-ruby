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

require "functions_framework"

FunctionsFramework.http "http" do |request|
  "I received: #{request.request_method} #{request.url}\n"
end

FunctionsFramework.event "event" do |data, context|
  puts "I received: #{data.inspect} in an event type #{context.type}\n"
end
