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

# Use the "modular app" interface.
require "sinatra/base"

# Define a simple Sinatra app.
class App < Sinatra::Base
  # You can use Sinatra to customize the middleware stack.
  use Rack::ShowStatus

  get "/" do
    "Sinatra received a request!"
  end

  get "/hello/:name" do
    "Hello, #{params[:name]}!"
  end

  get "/four-hundred" do
    400
  end
end

# Create an HTTP function that calls the Sinatra app.
FunctionsFramework.http "sinatra_example" do |request|
  App.call request.env
end
