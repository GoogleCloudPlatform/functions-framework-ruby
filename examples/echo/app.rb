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

# Create a simple HTTP function called "http_example"
FunctionsFramework.http "http_example" do |request|
  message = "I received a request: #{request.request_method} #{request.url}"
  request.logger.info message
  message
end

# Create a simple CloudEvents function called "event_example"
FunctionsFramework.cloud_event "event_example" do |event|
  FunctionsFramework.logger.info "I received #{event.data.inspect} in an event of type #{event.type}"
end
