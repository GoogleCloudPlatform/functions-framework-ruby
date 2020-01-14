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

require "json"

tool "server" do
  flag :port, accept: Integer
  required_arg :target, accept: String

  def run
    Dir.chdir context_directory
    cmd = ["bundle", "exec", "../../bin/functions-framework"]
    cmd += ["--port", port] if port
    cmd += ["--target", target] if target
    Kernel.exec(*cmd)
  end
end

tool "request" do
  flag :port, accept: Integer, default: 8080

  include :exec, e: true

  def run
    puts "Sending HTTP request"
    response = capture ["curl", "http://localhost:#{port}"]
    puts "Response: #{response.inspect}"
  end
end

tool "event" do
  flag :port, accept: Integer, default: 8080
  flag :encoding, default: "json", accept: ["json", "binary"]
  flag :type, default: "com.example.test"
  flag :source, default: "toys"
  flag :payload, default: "Payload created #{Time.now}"

  include :exec, e: true

  def run
    encoding == "json" ? run_json : run_binary
  end

  def create_random_id
    rand(100000000).to_s
  end

  def run_json
    struct = {
      id: create_random_id,
      source: source,
      type: type,
      specversion: "1.0",
      data: payload
    }
    puts "Sending JSON structured event with payload: #{payload.inspect}"
    response = capture [
      "curl",
      "--header", "Content-Type: application/cloudevents+json; charset=utf-8",
      "--data", JSON.dump(struct),
      "http://localhost:#{port}"
    ]
    puts "Response: #{response.inspect}"
  end

  def run_binary
    puts "Sending binary content event with payload: #{payload.inspect}"
    response = capture [
      "curl",
      "--header", "Content-Type: text/plain; charset=utf-8",
      "--header", "CE-ID: #{create_random_id}",
      "--header", "CE-Source: #{source}",
      "--header", "CE-Type: #{type}",
      "--header", "CE-Specversion: 1.0",
      "--data", payload,
      "http://localhost:#{port}"
    ]
    puts "Response: #{response.inspect}"
  end
end
