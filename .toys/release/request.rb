# frozen_string_literal: true

desc "Request a gem release"

long_desc \
  "This tool analyzes the commits since the last release, and updates the" \
    " library version and changelog accordingly. It opens a release pull" \
    " request with those changes. Typically, when this pull request is" \
    " merged, the post-push workflow will run automatically and perform the" \
    " release. This tool is normally called from a GitHub Actions workflow," \
    " but can also be executed locally.",
  "",
  "When invoked, this tool first performs checks including:",
  "* The git workspace must be clean (no new, modified, or deleted files)",
  "* The remote repo must be the correct repo configured in releases.yml",
  "* All GitHub checks for the release to commit must have succeeded",
  "",
  "The tool then creates release pull requests for each gem:",
  "* It collects all commit messages since the previous release",
  "* It builds a changelog using properly formatted conventional commit" \
    " messages of type 'fix', 'feat', and 'docs', and any that indicate a" \
    " breaking change.",
  "* It infers a new version number using the implied semver significance of" \
    " the commit messages.",
  "* It edits the changelog and version Ruby files and pushes a commit to a" \
    " release branch.",
  "* It opens a release pull request.",
  "",
  "The release pull request may be edited (to modify the version and/or" \
    " changelog before merging. Alternately, specific version numbers to" \
    " release can be specified via flags."

flag :gems, "--gems=VAL" do
  accept(/^([\w-]+(:[\w\.-]+)?([\s,]+[\w-]+(:[\w\.-]+)?)*)?$/)
  desc "Gems and versions to release"
  long_desc \
    "Specify a list of gems and optional versions. The format is a list of" \
      " comma and/or whitespace delimited strings of the form:",
    ["    <gemname>[:<version>]"],
    "",
    "If no version is specified for a gem, a version is inferred from the" \
      " conventional commit messages. If this flag is omitted or left blank," \
      " all gems in the repository that have at least one commit of type" \
      " 'fix', 'feat', or 'docs', or a breaking change, will be released."
end
flag :git_remote, "--git-remote=VAL" do
  default "origin"
  desc "The name of the git remote"
  long_desc \
    "The name of the git remote pointing at the canonical repository." \
    " Defaults to 'origin'."
end
flag :git_user_email, "--git-user-email=VAL" do
  desc "Git user email to use for new commits"
  long_desc \
    "Git user email to use for docs commits. If not provided, uses the" \
    " current global git setting. Required if there is no global setting."
end
flag :git_user_name, "--git-user-name=VAL" do
  desc "Git user email to use for new commits"
  long_desc \
    "Git user name to use for docs commits. If not provided, uses the" \
    " current global git setting. Required if there is no global setting."
end
flag :release_ref, "--release-ref=VAL" do
  desc "Branch name to use for the release"
  long_desc \
    "The branch to target the release. Should be the main branch."
end
flag :yes, "--yes", "-y" do
  desc "Automatically answer yes to all confirmations"
end

include :exec, exit_on_nonzero_status: true
include :terminal, styled: true
include :fileutils

def run
  require "release_utils"
  require "release_requester"

  cd context_directory
  utils = ReleaseUtils.new self

  [:release_ref, :git_user_email, :git_user_name].each do |key|
    set key, nil if get(key).to_s.empty?
  end

  instances = build_instances utils

  instances.each do |instance|
    next unless should_build instance
    instance.request
    puts "PR ##{instance.pr_number} opened for #{instance.gem_name} #{instance.new_version}.",
         :bold, :green
  end
end

def build_instances utils
  requester = ReleaseRequester.new utils,
                                   release_ref:    release_ref,
                                   git_remote:     git_remote,
                                   git_user_name:  git_user_name,
                                   git_user_email: git_user_email
  gem_list = gems.to_s.empty? ? utils.all_gems : gems.split(/[\s,]+/)
  gem_list.map do |gem_info|
    gem_name, override_version = gem_info.split ":", 2
    requester.instance gem_name, override_version: override_version
  end
end

def should_build instance
  if gems.to_s.empty? && instance.changelog_entries.empty?
    logger.info "Skipping #{instance.gem_name}"
    return false
  end
  unless yes
    if instance.last_version
      puts "Last #{instance.gem_name} version: #{instance.last_version}", :bold
    else
      puts "No previous #{instance.gem_name} version.", :bold
    end
    puts "New #{instance.gem_name} changelog:", :bold
    puts instance.full_changelog
    puts
    unless confirm "Create release PR? ", :bold, default: true
      logger.error "Release aborted"
      return false
    end
  end
  true
end
