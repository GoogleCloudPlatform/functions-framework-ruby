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

source "https://rubygems.org"

gemspec

gem "google-style", "~> 1.26.3"
gem "minitest", "~> 5.16"
gem "minitest-focus", "~> 1.2"
gem "minitest-rg", "~> 5.2"
gem "puma", ENV["FF_DEPENDENCY_TEST_PUMA"] if ENV["FF_DEPENDENCY_TEST_PUMA"]
gem "rack", ENV["FF_DEPENDENCY_TEST_RACK"] if ENV["FF_DEPENDENCY_TEST_RACK"]
gem "redcarpet", "~> 3.5" unless ::RUBY_PLATFORM == "java"
gem "yard", "~> 0.9.25"
