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

TESTS = ["unit", "rubocop", "yardoc", "build", "examples"]

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
  unless only
    TESTS.each do |name|
      key = "test_#{name}".to_sym
      set key, true if get(key).nil?
    end
  end
  exec_tool ["test"], name: "Tests" if test_unit
  exec_tool ["rubocop"], name: "Style checker" if test_rubocop
  exec_tool ["yardoc"], name: "Docs generation" if test_yardoc
  exec_tool ["build"], name: "Gem build" if test_build
  return unless test_examples
  ::Dir.foreach "examples" do |dir|
    next if dir =~ /^\.+$/
    exec ["toys", "test"], name: "Tests for #{dir} example", chdir: ::File.join("examples", dir)
  end
end
