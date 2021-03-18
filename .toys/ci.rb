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

desc "Run CI checks"

TESTS = ["unit", "rubocop", "yardoc", "build", "examples", "conformance"]

flag :only
TESTS.each do |name|
  flag "test_#{name}".to_sym, "--[no-]test-#{name}"
end

include :exec, result_callback: :handle_result
include :terminal

def handle_result result
  if result.success?
    puts "** #{result.name} passed\n\n", :green, :bold
  else
    puts "** CI terminated: #{result.name} failed!", :red, :bold
    exit 1
  end
end

def run
  ::Dir.chdir context_directory
  TESTS.each do |name|
    key = "test_#{name}".to_sym
    set key, !only if get(key).nil?
  end
  exec ["toys", "test"], name: "Unit tests" if test_unit
  exec ["toys", "rubocop"], name: "Style checker" if test_rubocop
  exec ["toys", "yardoc"], name: "Docs generation" if test_yardoc
  exec ["toys", "build"], name: "Gem build" if test_build
  ::Dir.foreach "examples" do |dir|
    next if dir =~ /^\.+$/
    exec ["toys", "test"], name: "Tests for #{dir} example", chdir: ::File.join("examples", dir)
  end if test_examples
  exec ["toys", "conformance"], name: "Conformance tests" if test_conformance
end
