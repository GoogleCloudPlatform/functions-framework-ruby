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

desc "Trigger a release of functions_framework"

include :exec, exit_on_nonzero_status: true
include :terminal
include :fileutils
include "release-tools"

required_arg :version
flag :yes
flag :git_remote, default: "origin"

def run
  cd context_directory

  puts "Running prechecks...", :bold
  verify_git_clean
  verify_library_version version
  changelog_entry = verify_changelog_content version
  verify_github_checks

  puts "Found changelog entry:", :bold
  puts changelog_entry
  if !yes && !confirm("Release functions_framework #{version}? ", :bold, default: true)
    error "Release aborted"
  end

  tag = "v#{version}"
  exec ["git", "tag", tag]
  exec ["git", "push", git_remote, tag]
  puts "SUCCESS: Pushed tag #{tag}", :green, :bold
end
