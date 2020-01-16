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

expand :clean, paths: ["pkg", "doc", ".yardoc", "tmp", "examples/*/vendor"]

expand :minitest, libs: ["lib", "test"]

expand :rubocop

expand :yardoc do |t|
  t.generate_output_flag = true
  t.fail_on_warning = true
  t.fail_on_undocumented_objects = true
end

expand :gem_build

expand :gem_build, name: "release", push_gem: true

expand :gem_build, name: "install", install_gem: true

tool "ci" do
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
    exec_tool ["test"], name: "Tests"
    exec_tool ["rubocop"], name: "Style checker"
    exec_tool ["yardoc"], name: "Docs generation"
  end
end
