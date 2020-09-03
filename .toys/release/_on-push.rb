# frozen_string_literal: true

desc "Perform post-push release tasks"

long_desc \
  "This tool is called by a GitHub Actions workflow after a commit is pushed" \
    " to the main branch. It triggers a release if applicable, or updates" \
    " existing release pull requests. Generally, this tool should not be" \
    " invoked manually."

flag :ci_result, "--ci-result=VAL" do
  default "success"
  desc "Result of the CI tasks"
  long_desc \
    "Set this flag to the result of the CI tasks: either 'success'," \
    " 'failure', or 'cancelled'."
end
flag :enable_releases, "--enable-releases=VAL" do
  default "true"
  desc "Control whether to enable releases."
  long_desc \
    "If set to 'true', releases will be enabled. Any other value will" \
    " result in dry-run mode, meaning it will go through the motions," \
    " create a GitHub release, and update the release pull request if" \
    " applicable, but will not actually push the gem to Rubygems or push" \
    " the docs to gh-pages."
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
flag :rubygems_api_key, "--rubygems-api-key=VAL" do
  desc "Set the Rubygems API key"
  long_desc \
    "Use the given Rubygems API key when pushing to Rubygems. Required if" \
    " and only if there is no current setting in the home Rubygems configs."
end

include :exec, exit_on_nonzero_status: true
include :fileutils
include :terminal, styled: true

def run
  require "release_utils"
  require "release_performer"

  cd context_directory
  @utils = ReleaseUtils.new self

  [:git_user_email, :git_user_name, :rubygems_api_key].each do |key|
    set key, nil if get(key).to_s.empty?
  end

  @pr_info = @utils.find_release_prs merge_sha: @utils.current_sha
  if @pr_info
    logger.info "This appears to be a merge of release PR #{@pr_info['number']}."
    handle_release_pr
  else
    logger.info "This was not a merge of a release PR."
    update_open_release_prs
    unless ci_result == "success"
      error "Exiting with an error code because the CI result was #{ci_result}."
    end
  end
end

def handle_release_pr
  gem_name = @pr_info["head"]["ref"].sub "release/", ""
  gem_version = @utils.current_library_version gem_name
  logger.info "The release is for #{gem_name} #{gem_version}."
  instance = create_performer_instance gem_name, gem_version
  if ci_result == "success"
    instance.perform
  else
    content = "Release of #{gem_name} #{gem_version} failed because the CI result was #{ci_result}."
    instance.report_release_error content
    @utils.error content
  end
end

def create_performer_instance gem_name, gem_version
  dry_run = /^t/i =~ enable_releases.to_s ? false : true
  performer = ReleasePerformer.new @utils,
                                   rubygems_api_key: rubygems_api_key,
                                   git_user_name:    git_user_name,
                                   git_user_email:   git_user_email,
                                   gh_token:         ::ENV["GITHUB_TOKEN"],
                                   docs_builder:     create_docs_builder,
                                   dry_run:          dry_run
  performer.instance gem_name, gem_version, pr_info: @pr_info
end

def create_docs_builder
  docs_builder_tool = @utils.docs_builder_tool
  return nil unless docs_builder_tool
  proc { exec_separate_tool Array(docs_builder_tool) }
end

def update_open_release_prs
  logger.info "Searching for open release PRs ..."
  prs = @utils.find_release_prs
  if prs.empty?
    logger.info "No existing release PRs to update."
    return
  end
  commit_message = capture ["git", "log", "-1", "--pretty=%B"]
  pr_message = <<~STR
    WARNING: An additional commit was added while this release PR was open.
    You may need to add to the changelog, or close this PR and prepare a new one.

    Commit link: https://github.com/#{@utils.repo_path}/commit/#{@utils.current_sha}

    Message:
    #{commit_message}
  STR
  prs.each do |pr_info|
    pr_number = pr_info["number"]
    logger.info "Updating PR #{pr_number} ..."
    @utils.update_release_pr pr_number, message: pr_message, cur_pr: pr_info
  end
  logger.info "Finished updating existing release PRs."
end
