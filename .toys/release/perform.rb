# frozen_string_literal: true

desc "Perform a gem release"

long_desc \
  "This tool performs an official gem release. It is normally called from a" \
    " GitHub Actions workflow, but can also be executed locally if the" \
    " proper credentials are present.",
  "",
  "In most cases, gems should be released using the 'prepare' tool, invoked" \
    " either locally or from GitHub Actions. That tool will automatically" \
    " update the library version and changelog based on the commits since" \
    " the last release, and will open a pull request that you can merge to" \
    " actually perform the release. The 'perform' tool should be used only" \
    " if the version and changelog commits are already committed.",
  "",
  "When invoked, this tool first performs checks including:",
  "* The git workspace must be clean (no new, modified, or deleted files)",
  "* The remote repo must be the correct repo configured in releases.yml",
  "* All GitHub checks for the release to commit must have succeeded",
  "* The gem version and changelog must be properly formatted and must match" \
    " the release version",
  "",
  "The tool then performs the necessary release tasks including:",
  "* Building the gem and pushing it to Rubygems",
  "* Building the docs and pushing it to gh-phages (if applicable)",
  "* Creating a GitHub release and tag"

exactly_one desc: "Trigger Type" do
  flag :ci_result, "--ci-result=VAL" do
    desc "Given the CI result, look for a merged release pull request."
    long_desc \
      "Use the release pull request whose merge commit is the current HEAD." \
      " The value must indicate the result of CI for the commit. If the" \
      " value is 'success', the release will proceed, otherwise the release" \
      " will be aborted. In either case, the pull request will be updated" \
      " with the result. If the current commit is not a merge of a release" \
      " pull request, no release is performed."
  end
  flag :gem, "--gem=VAL" do
    accept(/^[\w-]+:[\w\.-]+$/)
    desc "Release the given gem and version."
    long_desc \
      "Specify the exact gem and version to release, and do not update any" \
        " release pull requests. The value must be given in the form:",
      ["    <gem_name>:<version>"]
  end
end
flag_group desc: "Flags" do
  flag :enable_releases, "--enable-releases[=VAL]" do
    desc "Set to 'true' to enable releases."
    long_desc \
      "If set to 'true', releases will be enabled. Otherwise, the release will" \
      " proceed in dry-run mode, meaning it will go through the motions," \
      " create a GitHub release, and update the release pull request if" \
      " applicable, but will not actually push the gem to Rubygems or push the" \
      " docs to gh-pages."
  end
  flag :gh_pages_dir, "--gh-pages-dir=VAL" do
    desc "The directory to use for the gh-pages branch"
    long_desc \
      "Set to the path of a directory to use as the gh-pages workspace when" \
      " building and pushing gem documentation. If left unset, a temporary" \
      " directory will be created (and removed when finished)."
  end
  flag :git_remote, "--git-remote=VAL", default: "origin" do
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
  flag :github_sha, "--github-sha=VAL" do
    desc "SHA of the commit to use for the release"
    long_desc \
      "Specifies a particular SHA for the release. Optional. Defaults to the" \
      " current HEAD."
  end
  flag :only, "--only=VAL" do
    accept ["precheck", "gem", "docs", "github-release"]
    desc "Run only one part of the release process."
    long_desc \
      "Cause only one step of the release process to run.",
      "* 'precheck' runs only the pre-release checks.",
      "* 'gem' builds and pushes the gem to Rubygems.",
      "* 'docs' builds and pushes the docs to gh-pages.",
      "* 'github-release' tags and creates a GitHub release.",
      "",
      "Optional. If omitted, all steps are performed."
  end
  flag :rubygems_api_key, "--rubygems-api-key=VAL" do
    desc "Set the Rubygems API key"
    long_desc \
      "Use the given Rubygems API key when pushing to Rubygems. Required if" \
      " and only if there is no current setting in the home Rubygems configs."
  end
  flag :skip_checks, "--[no-]skip-checks" do
    desc "Disable pre-release checks"
    long_desc \
      "If set, all pre-release checks are disabled. This may occasionally be" \
      " useful to repair a broken release, but is generally not recommended."
  end
  flag :yes, "--yes", "-y" do
    desc "Automatically answer yes to all confirmations"
  end
end

include :exec, exit_on_nonzero_status: true
include :fileutils
include :terminal, styled: true

def run
  require "release_utils"
  require "release_perform"

  cd context_directory
  utils = ReleaseUtils.new self

  unless ::ENV["GITHUB_ACTIONS"]
    unless confirm "Perform a release locally, outside the normal process? ", :bold, :red
      utils.error "Release aborted"
    end
  end

  [:gh_pages_dir, :git_user_email, :git_user_name, :rubygems_api_key].each do |key|
    set key, nil if get(key).to_s.empty?
  end
  set :github_sha, utils.current_sha if github_sha.to_s.empty?

  if ci_result
    handle_post_push utils
  elsif gem
    gem_name, gem_version = gem.split ":", 2
    perform_release gem_name, gem_version, utils
  end
end

def handle_post_push utils
  pull = utils.find_release_prs merge_sha: github_sha
  if pull
    logger.info "This appears to be a merge of release PR #{pull['number']}."
    utils.on_error { |content| report_release_error pull, content, utils }
    gem_name = pull["head"]["ref"].sub "release/", ""
    gem_version = utils.current_library_version gem_name
    logger.info "The release is for #{gem_name} #{gem_version}."
    unless ci_result == "success"
      error "Release of #{gem_name} #{gem_version} failed because the CI result was #{ci_result}."
    end
    perform_release gem_name, gem_version, utils
    utils.clear_error_proc
    mark_release_pr_as_completed gem_name, gem_version, pull, utils
  else
    logger.info "This was not a merge of a release PR."
    update_open_release_prs utils
    unless ci_result == "success"
      error "Exiting with an error code because the CI result was #{ci_result}."
    end
  end
end

def perform_release gem_name, gem_version, utils
  docs_builder_tool = utils.gem_info gem_name, "docs_builder_tool"
  docs_builder = docs_builder_tool ? proc { exec_separate_tool Array(docs_builder_tool) } : nil
  dry_run = /^t/i =~ enable_releases.to_s ? false : true
  performer = ReleasePerform.new utils,
                                 release_sha:      github_sha,
                                 rubygems_api_key: rubygems_api_key,
                                 git_remote:       git_remote,
                                 git_user_name:    git_user_name,
                                 git_user_email:   git_user_email,
                                 gh_pages_dir:     gh_pages_dir,
                                 docs_builder:     docs_builder,
                                 dry_run:          dry_run
  instance = performer.instance gem_name, gem_version
  confirm_release gem_name, gem_version, utils
  instance.perform only: only
end

def confirm_release gem_name, gem_version, utils
  return if yes
  return if confirm "Release #{gem_name} #{gem_version}? ", :bold, default: false
  utils.error "Release aborted"
end

def mark_release_pr_as_completed gem_name, gem_version, pull, utils
  pr_number = pull["number"]
  logger.info "Updating release PR ##{pr_number} ..."
  message = "Released of #{gem_name} #{gem_version} complete!"
  utils.update_release_pr pr_number,
                          label:   utils.release_complete_label,
                          message: message,
                          cur_pr:  pull
  logger.info "Updated release PR."
end

def report_release_error pull, content, utils
  pr_number = pull["number"]
  logger.info "Updating the release PR ##{pr_number} to report an error ..."
  utils.update_release_pr pr_number,
                          label:   utils.release_error_label,
                          message: "Release failed.\n#{content}",
                          cur_pr:  pull
  logger.info "Opening a new issue to report the failure ..."
  body = <<~STR
    A release failed.

    Release PR: ##{pr_number}
    Commit: https://github.com/#{utils.repo_path}/commit/#{github_sha}

    Error message:
    #{content}
  STR
  title = "Release PR ##{pr_number} failed with an error"
  input = ::JSON.dump title: title, body: body
  response = capture ["gh", "api", "repos/#{utils.repo_path}/issues", "--input", "-",
                      "-H", "Accept: application/vnd.github.v3+json"],
                     in: [:string, input]
  issue_number = ::JSON.parse(response)["number"]
  logger.info "Issue #{issue_number} opened."
end

def update_open_release_prs utils
  logger.info "Searching for open release PRs ..."
  pulls = utils.find_release_prs
  if pulls.empty?
    logger.info "No existing release PRs to update."
    return
  end
  commit_message = capture ["git", "log", "-1", "--pretty=%B"]
  pr_message = <<~STR
    WARNING: An additional commit was added while this release PR was open.
    You may need to add to the changelog, or close this PR and prepare a new one.

    Commit link: https://github.com/#{utils.repo_path}/commit/#{github_sha}

    Message:
    #{commit_message}
  STR
  pulls.each do |pull|
    pr_number = pullpr["number"]
    logger.info "Updating PR #{pr_number} ..."
    utils.update_release_pr pr_number, message: pr_message, cur_pr: pull
  end
  logger.info "Finished updating existing release PRs."
end
