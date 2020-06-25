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

::Gem::Specification.new do |spec|
  spec.name = "functions_framework"
  spec.version = ::FunctionsFramework::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@google.com"]

  spec.summary = "Functions Framework for Ruby"
  spec.description =
    "The Functions Framework implementation for Ruby."
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

  spec.required_ruby_version = ">= 2.4.0"

  spec.add_dependency "puma", "~> 4.3"
  spec.add_dependency "rack", "~> 2.1"

  spec.add_development_dependency "google-style", "~> 1.24.0"
  spec.add_development_dependency "minitest", "~> 5.13"
  spec.add_development_dependency "minitest-focus", "~> 1.1"
  spec.add_development_dependency "minitest-rg", "~> 5.2"
  spec.add_development_dependency "redcarpet", "~> 3.5"
  spec.add_development_dependency "toys", "~> 0.10.0"
  spec.add_development_dependency "yard", "~> 0.9.24"
end
