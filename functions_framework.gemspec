# frozen_string_literal: true

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

lib = File.expand_path "lib", __dir__
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib
require "functions_framework/version"
version = ::FunctionsFramework::VERSION

::Gem::Specification.new do |spec|
  spec.name = "functions_framework"
  spec.version = version
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@google.com"]

  spec.summary = "Functions Framework for Ruby"
  spec.description =
    "The Functions Framework is an open source framework for writing " \
    "lightweight, portable Ruby functions that run in a serverless " \
    "environment. Functions written to this Framework will run on Google " \
    "Cloud Functions, Google Cloud Run, or any other Knative-based " \
    "environment."
  spec.license = "Apache-2.0"
  spec.homepage = "https://github.com/GoogleCloudPlatform/functions-framework-ruby"

  spec.files = ::Dir.glob("lib/**/*.rb") +
               ::Dir.glob("bin/*") +
               ::Dir.glob("*.md") +
               ::Dir.glob("docs/*.md") +
               ["LICENSE", ".yardopts"]
  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.executables = ["functions-framework", "functions-framework-ruby"]

  spec.required_ruby_version = ">= 3.0.0"
  spec.add_dependency "cloud_events", ">= 0.7.0", "< 2.a"
  spec.add_dependency "puma", ">= 4.3.0", "< 7.a"
  spec.add_dependency "rack", ">= 2.1", "< 4.a"

  if spec.respond_to? :metadata
    spec.metadata["changelog_uri"] =
      "https://googlecloudplatform.github.io/functions-framework-ruby/v#{version}/file.CHANGELOG.html"
    spec.metadata["source_code_uri"] = "https://github.com/GoogleCloudPlatform/functions-framework-ruby"
    spec.metadata["bug_tracker_uri"] = "https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues"
    spec.metadata["documentation_uri"] = "https://googlecloudplatform.github.io/functions-framework-ruby/v#{version}"
  end
end
