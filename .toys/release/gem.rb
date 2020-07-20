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

desc "Builds and releases the gem from the local checkout"

required_arg :version
flag :dry_run, "--[no-]dry-run", default: false

include :exec, exit_on_nonzero_status: true
include :terminal
include "release-tools"

def run
  ::Dir.chdir context_directory

  verify_git_clean warn_only: true
  verify_library_version version, warn_only: true
  verify_changelog_content version, warn_only: true
  verify_github_checks warn_only: true

  puts "WARNING: You are releasing locally, outside the normal process!", :bold, :red
  unless confirm "Build and push gems for version #{version}? ", default: false
    error "Release aborted"
  end

  build_gem version
  push_gem version, dry_run: dry_run
end
