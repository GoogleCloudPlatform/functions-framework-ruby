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
require "fileutils"

mixin "shared" do
  def vendor_framework do_vendor=true
    ::Dir.chdir context_directory do
      ::FileUtils.rm_rf "vendor"
      if do_vendor
        puts "Vendoring the current framework source into vendor/functions_framework"
        ::FileUtils.mkdir_p "vendor/functions_framework"
        ::FileUtils.cp_r "../../bin", "vendor/functions_framework/bin"
        ::FileUtils.cp_r "../../lib", "vendor/functions_framework/lib"
        ::FileUtils.cp_r "../../functions_framework.gemspec", "vendor/functions_framework/"
      else
        puts "Un-vendoring the framework and using the released gem"
      end
    end
  end

  def default_project
    `gcloud config get-value project`.strip
  end

  def default_tag
    ::Time.now.strftime "%Y%m%d%H%M%S"
  end
end

expand :clean, paths: "vendor"

tool "vendor-framework" do
  desc "Copies the current Functions Framework source into vendor/functions_framework"

  include "shared"

  def run
    vendor_framework
  end
end

tool "test" do
  desc "Run the app unit tests"

  flag :use_release, desc: "Use the released functions_framework gem instead of the local source"

  include "shared"
  include :exec, e: true

  def run
    vendor_framework !use_release
    ::Dir.chdir context_directory
    exec ["bundle", "install"]
    exec ["bundle", "exec", "ruby", "test/test_app.rb"]
  end
end

tool "server" do
  desc "Run the Functions Framework, serving the specified function"

  flag :target, accept: ::String, default: "sinatra_example", desc: "The name of the function to serve (defaults to sinatra_example)"
  flag :port, accept: ::Integer, default: 8080, desc: "The port to listen on (defaults to 8080)"
  flag :use_release, desc: "Use the released functions_framework gem instead of the local source"

  include "shared"
  include :exec, e: true

  def run
    vendor_framework !use_release
    ::Dir.chdir context_directory
    bin_path =
      if use_release
        "functions-framework-ruby"
      else
        "vendor/functions_framework/bin/functions-framework-ruby"
      end
    exec ["bundle", "install"]
    exec ["bundle", "exec", bin_path, "--target", target, "--port", port.to_s, "--detailed-errors"]
  end
end

tool "request" do
  desc "Send an HTTP request to a running Functions Framework"

  flag :https, desc: "Send request using https"
  flag :host, default: "localhost", desc: "The host to send request to (defaults to localhost)"
  flag :port, accept: ::Integer, default: 8080, desc: "The port to listen on (defaults to 8080)"
  flag :path, default: "", desc: "URL path"

  include :exec, e: true

  def run
    puts "Sending HTTP request"
    scheme = https ? "https" : "http"
    response = capture ["curl", "--silent", "#{scheme}://#{host}:#{port}/#{path}"]
    puts "Response: #{response.inspect}"
  end
end

tool "image" do
  desc "Tools related to running the framework in a local Docker container"

  tool "build" do
    desc "Build the functions into a local Docker image"

    flag :image, default: "functions-framework-sinatra-test", desc: "The Docker image name"
    flag :use_release, desc: "Use the released functions_framework gem instead of the local source"

    include "shared"
    include :exec, e: true

    def run
      vendor_framework !use_release
      ::Dir.chdir context_directory
      exec ["docker", "build", "--tag", image, "."]
    end
  end

  tool "server" do
    desc "Run the locally built Docker image"

    flag :image, default: "functions-framework-sinatra-test", desc: "The Docker image name"
    flag :port, accept: ::Integer, default: 8080, desc: "The port to listen on (defaults to 8080)"
    flag :target, accept: ::String, default: "sinatra_example", desc: "The name of the function to serve (defaults to sinatra_example)"

    include :exec, e: true

    def run
      exec ["docker", "run",
            "--rm", "-it", "-p", "#{port}:#{port}",
            image, "--port", port.to_s, "--target", target]
    end
  end
end

tool "run" do
  desc "Tools related to running the framework in Cloud Run"

  tool "deploy" do
    desc "Deploy the functions to Cloud Run"

    flag :project, accept: ::String, desc: "The project ID (defaults to the gcloud default project)"
    flag :app_name, default: "sinatra", desc: 'Name of the Cloud Run app (defaults to "sinatra")'
    flag :tag, accept: ::String, desc: "Docker tag used as a build ID (defaults to current timestamp)"
    flag :use_release, desc: "Use the released functions_framework gem instead of the local source"
    flag :target, accept: ::String, default: "sinatra_example", desc: "The name of the function to serve (defaults to sinatra_example)"

    include "shared"
    include :exec, e: true

    def run
      app_tag = tag || default_tag
      app_project = project || default_project
      image = "gcr.io/#{app_project}/#{app_name}:#{app_tag}"
      vendor_framework !use_release
      ::Dir.chdir context_directory
      exec ["gcloud", "builds", "submit", "--tag", image, "."]
      exec ["gcloud", "run", "deploy", app_name,
            "--image", image,
            "--platform", "managed",
            "--allow-unauthenticated",
            "--region", "us-central1",
            "--update-env-vars=FUNCTION_TARGET=#{target}"]
    end
  end

  tool "request" do
    desc "Send an HTTP request to a Functions Framework running in Cloud Run"

    required_arg :host, desc: "The host to send request to"
    flag :path, default: "", desc: "URL path"

    include :exec, e: true

    def run
      exit(cli.run(["request", "--https", "--host", host, "--port", "443", "--path", path], verbosity: verbosity))
    end
  end
end
