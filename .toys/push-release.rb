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

desc "Build and push a release of functions_framework"

include :exec, exit_on_nonzero_status: true
include :terminal
include :fileutils
include "release-tools"

flag :release_tag, accept: String, default: ::ENV["CIRCLE_TAG"]
flag :api_key, accept: String, default: ::ENV["RUBYGEMS_API_KEY"]
flag :enable_releases, default: (/^t/i =~ ::ENV["ENABLE_RELEASES"] ? true : false)

def run
  cd(context_directory)
  version = parse_tag(release_tag)
  puts("Releasing functions_framework #{version}...")
  verify_library_version(version)
  verify_changelog_content(version)
  using_api_key(api_key) do
    mkdir_p("pkg")
    built_file = "pkg/functions_framework-#{version}.gem"
    exec(["gem", "build", "functions_framework.gemspec", "-o", built_file])
    if enable_releases
      exec(["gem", "push", built_file])
      puts("SUCCESS: Released functions_framework #{version}", :green, :bold)
    else
      error("#{built_file} didn't get built.") unless ::File.file?(built_file)
      puts("SUCCESS: Mock release of functions_framework #{version}", :green, :bold)
    end
  end
end

def parse_tag(tag)
  match = /^v(\d+\.\d+\.\d+.*)$/.match(tag.to_s)
  error("Bad tag format: #{tag.inspect}") unless match
  match[1]
end

def using_api_key(key)
  home_dir = ::ENV["HOME"]
  creds_path = "#{home_dir}/.gem/credentials"
  creds_exist = ::File.exist?(creds_path)
  if creds_exist && !key
    puts("Using existing Rubygems credentials")
    yield
    return
  end
  error("API key not provided") unless key
  error("Cannot set API key because #{creds_path} already exists")if creds_exist
  begin
    mkdir_p("#{home_dir}/.gem")
    ::File.open(creds_path, "w", 0o600) do |file|
      file.puts("---\n:rubygems_api_key: #{api_key}")
    end
    puts("Using provided Rubygems credentials")
    yield
  ensure
    exec(["shred", "-u", creds_path])
  end
end
