# frozen_string_literal: true

require "fileutils"
require "release_utils"

# A class that creates release PRs
class ReleaseRequester
  def initialize utils,
                 release_ref: nil,
                 git_remote: nil,
                 git_user_name: nil,
                 git_user_email: nil
    @utils = utils
    @release_ref = release_ref || utils.current_branch
    @git_remote = git_remote || "origin"
    @git_user_name = git_user_name
    @git_user_email = git_user_email
    @performed_initial_setup = false
  end

  def initial_setup
    @utils.error "Releases must be requested from an existing branch" unless @release_ref
    @utils.verify_git_clean
    @utils.verify_repo_identity git_remote: @git_remote
    @utils.verify_github_checks ref: @release_ref
    if @utils.capture(["git", "rev-parse", "--is-shallow-repository"]).strip == "true"
      @utils.exec ["git", "fetch", "--unshallow", @git_remote, @release_ref]
    end
    @utils.exec ["git", "fetch", @git_remote, "--tags"]
    @utils.exec ["git", "config", "--local", "user.email", @git_user_email] if @git_user_email
    @utils.exec ["git", "config", "--local", "user.name", @git_user_name] if @git_user_name
    @utils.exec ["git", "checkout", @release_ref]
    @performed_initial_setup = true
  end

  def instance gem_name, override_version: nil
    initial_setup unless @performed_initial_setup
    Instance.new @utils, gem_name, override_version, @release_ref, @git_remote
  end

  # An instance of release PR preparation
  class Instance # rubocop:disable Metrics/ClassLength
    def initialize utils, gem_name, override_version, release_ref, git_remote
      @utils = utils
      @gem_name = gem_name
      @override_version = override_version
      @release_ref = release_ref
      @git_remote = git_remote
      @pr_number = nil
      verify_gem_name
      init_analysis
      determine_last_version
      analyze_messages
      determine_new_version
      build_changelog_entries
      build_full_changelog
      build_commit_info
    end

    attr_reader :gem_name
    attr_reader :last_version
    attr_reader :new_version
    attr_reader :changelog_entries
    attr_reader :date
    attr_reader :full_changelog
    attr_reader :release_commit_title
    attr_reader :release_branch_name
    attr_reader :pr_number

    def request
      modify_version_file
      modify_changelog_file
      create_release_commit
      create_release_pr
      self
    end

    private

    SEMVER_CHANGES = {
      "patch" => 2,
      "minor" => 1,
      "major" => 0
    }.freeze

    def verify_gem_name
      @utils.error "Gem #{@gem_name} not known." unless @utils.gem_info @gem_name
      prs = @utils.find_release_prs gem_name: @gem_name
      return if prs.empty?
      pr_number = prs.first["number"]
      @utils.error "A release PR ##{pr_number} already exists for #{@gem_name}"
    end

    def init_analysis
      @bump_segment = 2
      @feats = []
      @fixes = []
      @docs = []
      @breaks = []
      @others = []
    end

    def determine_last_version
      @last_version =
        @utils.capture(["git", "tag", "-l"])
              .split("\n")
              .map do |tag|
                if tag =~ %r{^#{@gem_name}/v(\d+\.\d+\.\d+)$}
                  ::Gem::Version.new ::Regexp.last_match 1
                end
              end
              .compact
              .max
    end

    def analyze_messages
      shas =
        if @last_version
          commits = "#{@gem_name}/v#{@last_version}^..#{@release_ref}"
          @utils.capture(["git", "log", commits, "--format=%H"]).split("\n").reverse
        else
          []
        end
      dir = @utils.gem_directory @gem_name
      (0..(shas.length - 2)).each do |index|
        sha1 = shas[index]
        sha2 = shas[index + 1]
        unless dir == "."
          files = @utils.capture ["git", "diff", "--name-only", "#{sha1}..#{sha2}"]
          next unless files.split("\n").any? { |file| file.start_with? dir }
        end
        message = @utils.capture ["git", "log", "#{sha1}..#{sha2}", "--format=%B"]
        analyze_message message
      end
    end

    def analyze_message message
      lines = message.split "\n"
      return if lines.empty?
      bump_segment = analyze_title lines.first
      bump_segment = analyze_body lines[1..-1], bump_segment
      @bump_segment = bump_segment if bump_segment < @bump_segment
    end

    def analyze_title title
      bump_segment = 2
      match = /^(fix|feat|docs)(?:\([^()]+\))?(!?):\s+(.*)$/.match title
      return bump_segment unless match
      description = normalize_line match[3], delete_pr_number: true
      case match[1]
      when "fix"
        @fixes << description
      when "docs"
        @docs << description
      when "feat"
        @feats << description
        bump_segment = 1 if bump_segment > 1
      end
      if match[2] == "!"
        bump_segment = 0
        @breaks << description
      end
      bump_segment
    end

    def analyze_body body, bump_segment
      footers = body.reduce nil do |list, line|
        if line.empty?
          []
        elsif list
          list << line
        end
      end
      lock_change = false
      return bump_segment unless footers
      footers.each do |line|
        match = /^(BREAKING CHANGE|[\w-]+):\s+(.*)$/.match line
        next unless match
        case match[1]
        when /^BREAKING[-\s]CHANGE$/
          bump_segment = 0 unless lock_change
          @breaks << normalize_line(match[2])
        when /^semver-change$/i
          seg = SEMVER_CHANGES[match[2].downcase]
          if seg
            bump_segment = seg
            lock_change = true
          end
        end
      end
      bump_segment
    end

    def normalize_line line, delete_pr_number: false
      match = /^([a-z])(.*)$/.match line
      line = match[1].upcase + match[2] if match
      line = line.gsub(/\(#\d+\)$/, "") if delete_pr_number
      line
    end

    def determine_new_version
      @new_version = @override_version
      if @last_version
        @new_version ||= begin
          segments = @last_version.segments
          @bump_segment = 1 if segments[0].zero? && @bump_segment.zero?
          segments[@bump_segment] += 1
          segments.fill(0, @bump_segment + 1).join(".")
        end
      else
        @new_version ||= "0.1.0"
        @others << "Initial release."
      end
      @new_version = ::Gem::Version.new @new_version
    end

    def build_changelog_entries
      @changelog_entries = []
      unless @breaks.empty?
        @breaks.each do |line|
          @changelog_entries << "* BREAKING CHANGE: #{line}"
        end
        @changelog_entries << ""
      end
      @feats.each do |line|
        @changelog_entries << "* Feature: #{line}"
      end
      @fixes.each do |line|
        @changelog_entries << "* Fix: #{line}"
      end
      @docs.each do |line|
        @changelog_entries << "* Documentation: #{line}"
      end
      @others.each do |line|
        @changelog_entries << "* #{line}"
      end
    end

    def build_full_changelog
      @date = ::Time.now.strftime "%Y-%m-%d"
      entries = @changelog_entries.empty? ? ["* (No significant changes)"] : @changelog_entries
      body = entries.join "\n"
      @full_changelog = "### v#{@new_version} / #{@date}\n\n#{body}"
    end

    def build_commit_info
      @release_commit_title = "release: Release #{@gem_name} #{@new_version}"
      @release_branch_name = @utils.release_branch_name @gem_name
    end

    def modify_version_file
      path = @utils.gem_version_rb_path @gem_name, from: :context
      content = ::File.read path
      content.sub!(/  VERSION = "\d+\.\d+\.\d+"/,
                   "  VERSION = \"#{@new_version}\"")
      ::File.open(path, "w") { |file| file.write content }
    end

    def modify_changelog_file
      path = @utils.gem_changelog_path @gem_name, from: :context
      content = ::File.read path
      content.sub! %r{\n### (v\d+\.\d+\.\d+ / \d\d\d\d-\d\d-\d\d)},
                   "\n#{@full_changelog}\n\n### \\1"
      ::File.open(path, "w") { |file| file.write content }
    end

    def create_release_commit
      if @utils.exec(["git", "rev-parse", "--verify", "--quiet", @release_branch_name], e: false).success?
        @utils.exec ["git", "branch", "-D", @release_branch_name]
      end
      @utils.exec ["git", "checkout", "-b", @release_branch_name]
      commit_cmd = ["git", "commit", "-a", "-m", @release_commit_title]
      commit_cmd << "--signoff" if @utils.signoff_commits?
      @utils.exec commit_cmd
      @utils.exec ["git", "push", "-f", @git_remote, @release_branch_name]
      @utils.exec ["git", "checkout", @release_ref]
    end

    def create_release_pr
      enable_automation = @utils.enable_release_automation?
      pr_body = enable_automation ? build_automation_pr_body : build_standalone_pr_body
      body = ::JSON.dump title:                 @release_commit_title,
                         head:                  @release_branch_name,
                         base:                  @utils.main_branch,
                         body:                  pr_body,
                         maintainer_can_modify: true
      response = @utils.capture ["gh", "api", "repos/#{@utils.repo_path}/pulls", "--input", "-",
                                 "-H", "Accept: application/vnd.github.v3+json"],
                                in: [:string, body]
      pr_info = ::JSON.parse response
      @pr_number = pr_info["number"]
      return unless enable_automation
      @utils.update_release_pr @pr_number, label: @utils.release_pending_label, cur_pr: pr_info
    end

    def build_automation_pr_body
      <<~STR
        ## Prepare release of #{@gem_name} #{@new_version}

        This pull request prepares a new release of #{@gem_name}, by modifying \
        the gem version and constructing an initial changelog based on \
        [conventional commit](https://conventionalcommits.org) messages. The \
        new changelog entry is also quoted below.

         *  To confirm this release, merge this pull request, ensuring the \
            #{@utils.release_pending_label.inspect} label is set. The release \
            script will trigger automatically on merge.
         *  To abort this release, close this pull request without merging.

        You can edit the changelog and/or release version before merging. \
        Note that the changelog header must retain the same format, and must \
        match the release version, or the release will not succeed.

        ---

        #{@full_changelog}
      STR
    end

    def build_standalone_pr_body
      <<~STR
        ## Prepare release of #{@gem_name} #{@new_version}

        This pull request prepares a new release of #{@gem_name}, by modifying \
        the gem version and constructing an initial changelog based on \
        [conventional commit](https://conventionalcommits.org) messages. The \
        new changelog entry is also quoted below.

        You can edit the changelog and/or release version before merging. \
        Note that the changelog header must retain the same format, and must \
        match the release version, or the release will not succeed.

        You can run the `release perform` script once these changes are merged.

        ---

        #{@full_changelog}
      STR
    end
  end
end
