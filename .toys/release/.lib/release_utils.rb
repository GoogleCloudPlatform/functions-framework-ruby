# frozen_string_literal: true

require "json"
require "yaml"
require "toys/utils/exec"

# Utilities for release tools
class ReleaseUtils # rubocop:disable Metrics/ClassLength
  def initialize tool_context
    @tool_context = tool_context
    release_info_path = @tool_context.find_data "releases.yml"
    load_release_info release_info_path
    @logger = @tool_context.logger
    @error_proc = nil
  end

  attr_reader :repo_path
  attr_reader :main_branch
  attr_reader :default_gem
  attr_reader :tool_context
  attr_reader :logger

  def repo_owner
    repo_path.split("/").first
  end

  def all_gems
    @gems.keys
  end

  def gem_info gem_name, key = nil
    info = @gems[gem_name]
    key ? info[key] : info
  end

  def gem_directory gem_name, from: :context
    path = gem_info gem_name, "directory"
    case from
    when :context
      path
    when :absolute
      ::File.expand_path path, @tool_context.context_directory
    else
      raise "Unknown from value: #{from.inspect}"
    end
  end

  def gem_changelog_path gem_name, from: :directory
    path = gem_info gem_name, "changelog_path"
    case from
    when :directory
      path
    when :context
      ::File.expand_path path, gem_directory(gem_name)
    when :absolute
      ::File.expand_path path, gem_directory(gem_name, from: :absolute)
    else
      raise "Unknown from value: #{from.inspect}"
    end
  end

  def gem_version_rb_path gem_name, from: :directory
    path = gem_info gem_name, "version_rb_path"
    case from
    when :directory
      path
    when :context
      ::File.expand_path path, gem_directory(gem_name)
    when :absolute
      ::File.expand_path path, gem_directory(gem_name, from: :absolute)
    else
      raise "Unknown from value: #{from.inspect}"
    end
  end

  def gem_version_constant gem_name
    gem_info gem_name, "version_constant"
  end

  def gem_cd gem_name, &block
    dir = gem_directory gem_name, from: :absolute
    ::Dir.chdir dir, &block
  end

  def release_pending_label
    "release: pending"
  end

  def release_error_label
    "release: error"
  end

  def release_aborted_label
    "release: aborted"
  end

  def release_complete_label
    "release: complete"
  end

  def release_branch_name gem_name
    "release/#{gem_name}"
  end

  def current_sha ref = nil
    capture(["git", "rev-parse", ref || "HEAD"]).strip
  end

  def current_branch
    branch = capture(["git", "branch", "--show-current"]).strip
    branch.empty? ? nil : branch
  end

  def git_remote_url remote
    capture(["git", "remote", "get-url", remote]).strip
  end

  def exec cmd, **opts, &block
    @tool_context.exec cmd, **opts, &block
  end

  def capture cmd, **opts, &block
    @tool_context.capture cmd, **opts, &block
  end

  def find_release_prs gem_name: nil, merge_sha: nil, label: nil
    label ||= release_pending_label
    args = {
      state:     merge_sha ? "closed" : "open",
      sort:      "updated",
      direction: "desc",
      per_page:  20
    }
    if gem_name
      args[:head] = "#{repo_owner}:#{release_branch_name gem_name}"
      args[:sort] = "created"
    end
    query = args.map { |k, v| "#{k}=#{v}" }.join "&"
    output = capture ["gh", "api", "repos/#{repo_path}/pulls?#{query}",
                      "-H", "Accept: application/vnd.github.v3+json"]
    pulls = ::JSON.parse output
    if merge_sha
      pulls.find do |pull|
        pull["merged_at"] && pull["merge_commit_sha"] == merge_sha &&
          pull["labels"].any? { |label_info| label_info["name"] == label }
      end
    else
      pulls.find_all do |pull|
        pull["labels"].any? { |label_info| label_info["name"] == label }
      end
    end
  end

  def load_pr pr_number
    output = capture ["gh", "api", "repos/#{repo_path}/pulls/#{pr_number}",
                      "-H", "Accept: application/vnd.github.v3+json"]
    ::JSON.parse output
  end

  def update_release_pr pr_number, label: nil, message: nil, state: nil, cur_pr: nil
    update_pr_label pr_number, label, cur_pr: cur_pr if label
    update_pr_state pr_number, cur_pr: cur_pr if state
    add_pr_message pr_number, message if message
    self
  end

  def update_pr_label pr_number, label, cur_pr: nil
    cur_pr ||= load_pr pr_number
    cur_labels = cur_pr["labels"].map { |label_info| label_info["name"] }
    release_labels, other_labels = cur_labels.partition { |name| name.start_with? "release: " }
    return if release_labels == [label]
    body = ::JSON.dump labels: other_labels + [label]
    exec ["gh", "api", "-XPATCH", "repos/#{repo_path}/issues/#{pr_number}",
          "--input", "-", "-H", "Accept: application/vnd.github.v3+json"],
         in: [:string, body], out: :null
    self
  end

  def update_pr_state pr_number, state, cur_pr: nil
    cur_pr ||= load_pr pr_number
    return if cur_pr["state"] == state
    body = ::JSON.dump state: state
    exec ["gh", "api", "-XPATCH", "repos/#{repo_path}/pulls/#{pr_number}",
          "--input", "-", "-H", "Accept: application/vnd.github.v3+json"],
         in: [:string, body], out: :null
    self
  end

  def add_pr_message pr_number, message
    body = ::JSON.dump body: message
    exec ["gh", "api", "repos/#{repo_path}/issues/#{pr_number}/comments",
          "--input", "-", "-H", "Accept: application/vnd.github.v3+json"],
         in: [:string, body], out: :null
    self
  end

  def current_library_version gem_name
    path = gem_version_rb_path gem_name, from: :absolute
    require path
    const = ::Object
    gem_version_constant(gem_name).each do |name|
      const = const.const_get name
    end
    const
  end

  def verify_library_version gem_name, gem_vers
    @logger.info "Verifying #{gem_name} version file ..."
    lib_vers = current_library_version gem_name
    if gem_vers == lib_vers
      @logger.info "Version file OK"
    else
      path = gem_version_rb_path gem_name, from: :absolute
      error "Requested version #{gem_vers} doesn't match #{gem_name} library version #{lib_vers}.",
            "Modify #{path} and set VERSION = #{gem_vers.inspect}"
    end
    lib_vers
  end

  def verify_changelog_content gem_name, gem_vers # rubocop:disable Metrics/MethodLength
    @logger.info "Verifying #{gem_name} changelog content..."
    changelog_path = gem_changelog_path gem_name, from: :context
    today = ::Time.now.strftime "%Y-%m-%d"
    entry = []
    state = :start
    ::File.readlines(changelog_path).each do |line|
      case state
      when :start
        if line =~ %r{^### v#{::Regexp.escape gem_vers} / \d\d\d\d-\d\d-\d\d\n$}
          entry << line
          state = :during
        elsif line =~ /^### /
          error "The first changelog entry in #{changelog_path} isn't for version #{gem_vers}.",
                "It should start with:",
                "### v#{gem_vers} / #{today}",
                "But it actually starts with:",
                line
        end
      when :during
        if line =~ /^### /
          state = :after
        else
          entry << line
        end
      end
    end
    if entry.empty?
      error "The changelog #{changelog_path} doesn't have any entries.",
            "The first changelog entry should start with:",
            "### v#{gem_vers} / #{today}"
    else
      @logger.info "Changelog OK"
    end
    entry.join
  end

  def verify_repo_identity git_remote: "origin"
    @logger.info "Verifying git repo identity ..."
    url = git_remote_url git_remote
    cur_repo =
      case url
      when %r{^git@github.com:([^/]+/[^/]+)\.git$}
        ::Regexp.last_match 1
      when %r{^https://github.com/([^/]+/[^/]+)/?$}
        ::Regexp.last_match 1
      else
        error "Unrecognized remote url: #{url.inspect}"
      end
    if cur_repo == repo_path
      @logger.info "Git repo is correct."
    else
      error "Remmote repo is #{cur_repo}, expected #{repo_path}"
    end
    cur_repo
  end

  def verify_git_clean
    @logger.info "Verifying git clean..."
    output = capture(["git", "status", "-s"]).strip
    if output.empty?
      @logger.info "Git working directory is clean."
    else
      error "There are local git changes that are not committed."
    end
    self
  end

  def verify_github_checks ref: nil
    @logger.info "Verifying GitHub checks ..."
    ref = current_sha ref
    result = exec ["gh", "api", "repos/#{repo_path}/commits/#{ref}/check-runs",
                   "-H", "Accept: application/vnd.github.antiope-preview+json"],
                  out: :capture, e: false
    error "Failed to obtain GitHub check results for #{ref}" unless result.success?
    results = ::JSON.parse result.captured_out
    checks = results["check_runs"]
    error "No GitHub checks found for #{ref}" if checks.empty?
    error "GitHub check count mismatch for #{ref}" unless checks.size == results["total_count"]
    checks.each do |check|
      name = check["name"]
      next unless name.start_with? "test"
      unless check["status"] == "completed"
        error "GitHub check #{name.inspect} is not complete"
      end
      unless check["conclusion"] == "success"
        error "GitHub check #{name.inspect} was not successful"
      end
    end
    @logger.info "GitHub checks all passed."
    self
  end

  def error message, *more_messages
    if ::ENV["GITHUB_ACTIONS"]
      puts "::error::#{message}"
    else
      @tool_context.puts message, :red, :bold
    end
    more_messages.each { |m| @tool_context.puts m }
    if @error_proc
      content = ([message] + more_messages).join "\n"
      @error_proc.call content
    end
    sleep 1
    @tool_context.exit 1
  end

  def warning message
    if ::ENV["GITHUB_ACTIONS"]
      puts "::warning::#{message}"
    else
      @logger.warn message
    end
  end

  def on_error &block
    @error_proc = block
    self
  end

  def clear_error_proc
    @error_proc = nil
  end

  private

  def load_release_info file_path
    error "Unable to find releases.yml data file" unless file_path
    info = ::YAML.load_file file_path
    @main_branch = info["main_branch"] || "main"
    @repo_path = info["repo"]
    error "Repo key missing from releases.yml" unless @repo_path
    @gems = {}
    @default_gem = nil
    has_multiple_gems = info["gems"].size > 1
    info["gems"].each do |gem_info|
      name = gem_info["name"]
      error "Name missing from gem in releases.yml" unless name
      add_gem_defaults gem_info, name, has_multiple_gems
      @gems[name] = gem_info
      @default_gem ||= name
    end
    error "Repo key missing from releases.yml" unless @default_gem
  end

  def add_gem_defaults gem_info, name, has_multiple_gems
    gem_info["directory"] ||= has_multiple_gems ? name : "."
    segments = name.split "-"
    name_path = segments.join "/"
    gem_info["version_rb_path"] ||= "lib/#{name_path}/version.rb"
    gem_info["changelog_path"] ||= "CHANGELOG.md"
    gem_info["version_constant"] ||= segments.map { |seg| camelize seg } + ["VERSION"]
    gem_info["gh_pages_directory"] ||= has_multiple_gems ? name : "."
    gem_info["gh_pages_version_var"] ||=
      has_multiple_gems ? "version_#{name}".tr("-", "_") : "version"
    gem_info["enable_release_automation"] = true if gem_info["enable_release_automation"].nil?
  end

  def camelize str
    str.to_s
       .sub(/^_/, "")
       .sub(/_$/, "")
       .gsub(/_+/, "_")
       .gsub(/(?:^|_)([a-zA-Z])/) { ::Regexp.last_match(1).upcase }
  end
end
