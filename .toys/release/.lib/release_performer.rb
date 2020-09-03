# frozen_string_literal: true

require "base64"
require "fileutils"
require "tmpdir"
require "release_utils"

# A class that performs releases
class ReleasePerformer
  # A release instance
  class Instance
    # @private
    def initialize parent, gem_name, gem_version, pr_info, step
      @parent = parent
      @gem_name = gem_name
      @gem_version = gem_version
      @pr_info = pr_info
      @utils = parent.utils
      @include_gem = ["all", "gem"].include? step
      @include_docs = !@utils.docs_builder.nil? && ["all", "docs"].include?(step)
      @include_github_release = ["all", "github-release"].include? step
    end

    attr_reader :gem_name
    attr_reader :gem_version

    def perform
      @utils.on_error { |content| report_release_error content }
      @parent.initial_setup
      verify unless @parent.skip_checks?

      build_gem if @include_gem
      if @include_docs
        build_docs
        set_default_docs_version if @gem_version =~ /^\d+\.\d+\.\d+$/
      end

      create_github_release @changelog_content if @include_github_release
      push_gem if @include_gem
      push_docs if @include_docs

      @utils.clear_error_proc
      report_release_complete
      self
    end

    private

    def verify
      @utils.verify_library_version @gem_name, @gem_version
      @changelog_content = @utils.verify_changelog_content @gem_name, @gem_version
      self
    end

    def create_github_release content = nil
      @utils.logger.info "Creating github release of #{@gem_name} #{@gem_version} ..."
      body = ::JSON.dump tag_name:         "#{@gem_name}/v#{@gem_version}",
                         target_commitish: @parent.release_sha,
                         name:             "#{@gem_name} #{@gem_version}",
                         body:             content.strip
      @utils.exec ["gh", "api", "repos/#{@utils.repo_path}/releases", "--input", "-",
                   "-H", "Accept: application/vnd.github.v3+json"],
                  in: [:string, body], out: :null
      @utils.logger.info "Release created."
      self
    end

    def build_gem
      @utils.logger.info "Building #{@gem_name} #{@gem_version} gem ..."
      @utils.gem_cd @gem_name do
        ::FileUtils.mkdir_p "pkg"
        @utils.exec ["gem", "build", "#{@gem_name}.gemspec",
                     "-o", "pkg/#{@gem_name}-#{@gem_version}.gem"]
      end
      @utils.logger.info "Gem built"
      self
    end

    def push_gem
      @utils.logger.info "Pushing #{@gem_name} #{@gem_version} to Rubygems ..."
      @utils.gem_cd @gem_name do
        built_file = "pkg/#{@gem_name}-#{@gem_version}.gem"
        @utils.error "#{built_file} didn't get built." unless ::File.file? built_file
        if @parent.dry_run?
          @utils.logger.info "DRY RUN: Gem pushed to Rubygems"
        else
          @utils.exec ["gem", "push", built_file]
          @utils.logger.info "Gem pushed to Rubygems"
        end
      end
      self
    end

    def build_docs
      @utils.error "Cannot build docs" unless @utils.docs_builder
      @utils.logger.info "Building #{@gem_name} #{@gem_version} docs..."
      @utils.gem_cd @gem_name do
        ::FileUtils.rm_rf ".yardoc"
        ::FileUtils.rm_rf "doc"
        @utils.docs_builder.call
        path = ::File.expand_path @utils.gem_info(@gem_name, "gh_pages_directory"),
                                  @parent.gh_pages_dir
        path = ::File.expand_path "v#{@gem_version}", path
        ::FileUtils.rm_rf path
        ::FileUtils.cp_r "doc", path
      end
      @utils.logger.info "Built docs"
      self
    end

    def set_default_docs_version
      @utils.error "Cannot set default #{@gem_name} docs version" unless @utils.docs_builder
      @utils.logger.info "Changing default #{@gem_name} docs version to #{@gem_version}..."
      path = "#{@parent.gh_pages_dir}/404.html"
      content = ::IO.read path
      var_name = @utils.gem_info @gem_name, "gh_pages_version_var"
      content.sub!(/#{var_name} = "[\w\.]+";/,
                   "#{var_name} = \"#{@gem_version}\";")
      ::File.open path, "w" do |file|
        file.write content
      end
      @utils.logger.info "Updated redirects."
      self
    end

    def push_docs
      @utils.logger.info "Pushing #{@gem_name} docs to gh-pages ..."
      ::Dir.chdir @parent.gh_pages_dir do
        @utils.exec ["git", "add", "."]
        commit_cmd = ["git", "commit", "-m", "Generate yardocs for #{@gem_name} #{@gem_version}"]
        commit_cmd << "--signoff" if @utils.signoff_commits?
        @utils.exec commit_cmd
        @utils.exec ["git", "push", @parent.git_remote, "gh-pages"]
      end
      @utils.logger.info "Docs pushed to gh-pages"
      self
    end

    def report_release_error content
      return unless @pr_info
      pr_number = @pr_info["number"]
      @utils.logger.info "Updating the release PR ##{pr_number} to report an error ..."
      @utils.update_release_pr pr_number,
                               label:   @utils.release_error_label,
                               message: "Release failed.\n#{content}",
                               cur_pr:  @pr_info
      @utils.logger.info "Opening a new issue to report the failure ..."
      body = <<~STR
        A release failed.

        Release PR: ##{pr_number}
        Commit: https://github.com/#{@utils.repo_path}/commit/#{@parent.release_sha}

        Error message:
        #{content}
      STR
      title = "Release PR ##{pr_number} failed with an error"
      input = ::JSON.dump title: title, body: body
      response = @utils.capture ["gh", "api", "repos/#{@utils.repo_path}/issues", "--input", "-",
                                 "-H", "Accept: application/vnd.github.v3+json"],
                                in: [:string, input]
      issue_number = ::JSON.parse(response)["number"]
      @utils.logger.info "Issue #{issue_number} opened."
      self
    end

    def report_release_complete
      return unless @pr_info
      pr_number = @pr_info["number"]
      @utils.logger.info "Marking release PR ##{pr_number} complete ..."
      message = "Released of #{@gem_name} #{@gem_version} complete!"
      @utils.update_release_pr pr_number,
                               label:   @utils.release_complete_label,
                               message: message,
                               cur_pr:  @pr_info
      @utils.logger.info "Updated release PR."
    end
  end

  def initialize utils,
                 release_sha: nil,
                 skip_checks: false,
                 rubygems_api_key: nil,
                 git_remote: nil,
                 git_user_name: nil,
                 git_user_email: nil,
                 gh_pages_dir: nil,
                 gh_token: nil,
                 dry_run: false
    @utils = utils
    @release_sha = @utils.current_sha release_sha
    @skip_checks = skip_checks
    @rubygems_api_key = rubygems_api_key
    @git_remote = git_remote || "origin"
    @git_user_name = git_user_name
    @git_user_email = git_user_email
    @dry_run = dry_run
    @gh_pages_dir = gh_pages_dir
    @gh_token = gh_token
    @performed_initial_setup = false
  end

  attr_reader :utils
  attr_reader :release_sha
  attr_reader :rubygems_api_key
  attr_reader :gh_pages_dir
  attr_reader :git_remote

  def dry_run?
    @dry_run
  end

  def skip_checks?
    @skip_checks
  end

  def instance gem_name, gem_version, pr_info: nil, only: nil
    Instance.new self, gem_name, gem_version, pr_info, only || "all"
  end

  def initial_setup
    return if @performed_initial_setup
    unless @skip_checks
      @utils.verify_git_clean
      @utils.verify_repo_identity git_remote: @git_remote
      @utils.verify_github_checks ref: @release_sha
    end
    if @utils.docs_builder
      setup_gh_pages
    else
      @gh_pages_dir = nil
    end
    setup_rubygems_api_key
    @performed_initial_setup = true
  end

  private

  def setup_gh_pages
    if @gh_pages_dir
      ::FileUtils.remove_entry @gh_pages_dir, true
      ::FileUtils.mkdir_p @gh_pages_dir
    else
      dir = ::Dir.mktmpdir
      at_exit { ::FileUtils.remove_entry dir, true }
      @gh_pages_dir = dir
    end
    remote_url = @utils.git_remote_url @git_remote
    ::Dir.chdir @gh_pages_dir do
      @utils.exec ["git", "init"]
      @utils.exec ["git", "config", "--local", "user.email", @git_user_email] if @git_user_email
      @utils.exec ["git", "config", "--local", "user.name", @git_user_name] if @git_user_name
      if remote_url.start_with?("https://github.com/") && @gh_token
        encoded_token = ::Base64.strict_encode64 "x-access-token:#{@gh_token}"
        @utils.exec ["git", "config", "--local", "http.https://github.com/.extraheader",
                     "Authorization: Basic #{encoded_token}"],
                    log_cmd: '["git", "config", "--local", "http.https://github.com/.extraheader", "****"]'
      end
      @utils.exec ["git", "remote", "add", @git_remote, remote_url]
      @utils.exec ["git", "fetch", "--no-tags", "--depth=1", "--no-recurse-submodules", @git_remote, "gh-pages"]
      @utils.exec ["git", "branch", "gh-pages", "#{@git_remote}/gh-pages"]
      @utils.exec ["git", "checkout", "gh-pages"]
    end
  end

  def setup_rubygems_api_key
    home_dir = ::ENV["HOME"]
    creds_path = "#{home_dir}/.gem/credentials"
    creds_exist = ::File.exist? creds_path
    if creds_exist && @rubygems_api_key
      @utils.error "Cannot set Rubygems credentials because #{creds_path} already exists"
    end
    if !creds_exist && !@rubygems_api_key
      @utils.error "Rubygems credentials needed but not provided"
    end
    if creds_exist && !@rubygems_api_key
      @utils.logger.info "Using existing Rubygems credentials"
      return
    end
    ::FileUtils.mkdir_p "#{home_dir}/.gem"
    ::File.open creds_path, "w", 0o600 do |file|
      file.puts "---\n:rubygems_api_key: #{@rubygems_api_key}"
    end
    utils = @utils
    at_exit { utils.exec ["shred", "-u", creds_path] }
    @utils.logger.info "Using provided Rubygems credentials"
  end
end
