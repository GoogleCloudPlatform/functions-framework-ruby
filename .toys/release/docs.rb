# frozen_string_literal: true

desc "Pushes docs to gh-pages from the local checkout"

required_arg :version
flag :tmp_dir, default: "tmp"
flag :set_default_version, "--[no-]set-default-version", default: true
flag :dry_run, "--[no-]dry-run", default: false
flag :git_remote, "--git-remote=NAME", default: "origin"

include :exec, exit_on_nonzero_status: true
include :fileutils
include :terminal
include "release-tools"

def run
  cd context_directory

  verify_git_clean warn_only: true
  verify_library_version version, warn_only: true
  verify_changelog_content version, warn_only: true
  verify_github_checks warn_only: true

  puts "WARNING: You are pushing docs locally, outside the normal process!", :bold, :red
  unless confirm "Build and push yardocs for version #{version}? ", :bold
    error "Push aborted"
  end

  mkdir_p tmp_dir
  cd tmp_dir do
    rm_rf "sdk-ruby"
    exec ["git", "clone", "git@github.com:GoogleCloudPlatform/functions-framework-ruby.git"]
  end
  gh_pages_dir = "#{tmp_dir}/sdk-ruby"
  cd gh_pages_dir do
    exec ["git", "checkout", "gh-pages"]
  end

  build_docs version, gh_pages_dir
  set_default_docs version, gh_pages_dir if set_default_version

  push_docs version, gh_pages_dir, dry_run: dry_run, git_remote: git_remote
end
