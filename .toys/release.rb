# frozen_string_literal: true

# Copyright 2021 Google LLC
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

load_git remote: "https://github.com/googleapis/ruby-common-tools.git",
         path: "toys/release"

tool "publish-gh-pages" do
  flag :dry_run, default: ENV["RELEASE_DRY_RUN"] == "true"
  flag :github_token, "--github-token=TOKEN", default: ENV["GITHUB_TOKEN"]

  include :exec, e: true

  def run
    build_docs
    pull_gh_pages
    copy_gh_pages
    update_gh_pages_version
    push_gh_pages
  end

  def build_docs
    Dir.chdir context_directory do
      FileUtils.rm_rf "doc"
      FileUtils.rm_rf ".yardoc"
      exec ["toys", "yardoc"]
    end
  end

  def pull_gh_pages
    require "base64"
    Dir.chdir gh_pages_dir do
      exec ["git", "init"]
      exec ["git", "config", "--local", "user.name", "Google APIs"]
      exec ["git", "config", "--local", "user.email", "googleapis-packages@google.com"]
      if github_token && !github_token.empty? && github_remote.start_with?("https://")
        encoded_token = Base64.strict_encode64("x-access-token:#{github_token}")
        log_cmd = '["git", "config", "--local", "http.https://github.com/.extraheader", "****"]'
        exec ["git", "config", "--local", "http.https://github.com/.extraheader",
              "Authorization: Basic #{encoded_token}"],
             log_cmd: log_cmd
      end
      exec ["git", "remote", "add", "origin", github_remote]
      exec ["git", "fetch", "--no-tags", "--depth=1", "--no-recurse-submodules", "origin", "gh-pages"]
      exec ["git", "branch", "gh-pages", "origin/gh-pages"]
      exec ["git", "checkout", "gh-pages"]
    end
  end

  def copy_gh_pages
    Dir.chdir context_directory do
      logger.info "Copying docs into v#{gem_version}"
      dest_path = File.join gh_pages_dir, "v#{gem_version}"
      logger.warn "Replacing existing directory" if File.directory? dest_path
      FileUtils.rm_rf dest_path
      FileUtils.cp_r "doc", dest_path
      logger.info "Copied docs"
    end
  end

  def update_gh_pages_version
    Dir.chdir gh_pages_dir do
      logger.info "Updating default version in 404.html"
      filename = "404.html"
      content = IO.read filename
      var_name = "version"
      if /version = "([\w\.]+)";/ =~ content
        logger.info "Previous default version was #{Regexp.last_match[1]}"
      else
        logger.error "Unable to find current default version!"
      end
      content.sub!(/version = "[\w\.]+";/, "version = \"#{gem_version}\";")
      ::File.open filename, "w" do |file|
        file.write content
      end
      logger.info "Default version is now #{gem_version}"
    end
  end

  def push_gh_pages
    Dir.chdir gh_pages_dir do
      exec ["git", "add", "."]
      exec ["git", "commit", "-m", "Generate yardocs for functions_framework #{gem_version}"]
      if dry_run
        logger.warn "Dry run: Skipping git push"
      else
        exec ["git", "push", "origin", "gh-pages"]
      end
    end
  end

  def gh_pages_dir
    @gh_pages_dir ||= begin
      require "tmpdir"
      dir = Dir.mktmpdir
      logger.info "Using gh pages dir #{dir}"
      at_exit do
        FileUtils.remove_entry dir, true
      end
      dir
    end
  end

  def github_remote
    @github_remote ||=
      Dir.chdir context_directory do
        capture(["git", "remote", "get-url", "origin"]).strip
      end
  end

  def gem_version
    @gem_version ||= begin
      func = proc do
        Dir.chdir context_directory do
          spec = Gem::Specification.load "functions_framework.gemspec"
          puts spec.version
        end
      end
      value = capture_proc(func).strip
      logger.info "Specification gem version = #{value}"
      Gem::Version.new value
    end
  end
end
