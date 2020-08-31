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

desc "Run all CI checks"

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
  exec_tool ["test"], name: "Tests"
  exec_tool ["rubocop"], name: "Style checker"
  exec_tool ["yardoc"], name: "Docs generation"
  exec_tool ["build"], name: "Gem build"
  ::Dir.foreach "examples" do |dir|
    next if dir =~ /^\.+$/
    exec ["toys", "test"], name: "Tests for #{dir} example", chdir: ::File.join("examples", dir)
  end
end
