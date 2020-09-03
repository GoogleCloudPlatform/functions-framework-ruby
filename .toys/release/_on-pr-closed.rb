# frozen_string_literal: true

desc "Perform pull-request-closed release tasks"

long_desc \
  "This tool is called by a GitHub Actions workflow after a pull request is" \
    " closed. If the pull request was a release pull request and was not" \
    " merged, it marks the pull request as aborted. Generally, this tool" \
    " should not be invoked manually."

flag :event_path, "--event-path=VAL" do
  default ::ENV["GITHUB_EVENT_PATH"]
  desc "Path to the pull request closed event JSON file"
end

include :exec, exit_on_nonzero_status: true
include :fileutils
include :terminal, styled: true

def run
  require "release_utils"

  cd context_directory
  @utils = ReleaseUtils.new self

  @utils.error "GitHub event path missing" unless event_path
  pr_info = ::JSON.parse(::File.read(event_path))["pull_request"]
  pr_number = pr_info["number"]

  if pr_info["merged_at"]
    logger.info "PR #{pr_number} is merged. Ignoring."
    return
  end
  if pr_info["labels"].all? { |label_info| label_info["name"] != @utils.release_pending_label }
    logger.info "PR #{pr_number} does not have the pending label. Ignoring."
    return
  end

  logger.info "Updating release PR #{pr_number} to mark it as aborted."
  @utils.update_release_pr pr_number,
                           label:   @utils.release_aborted_label,
                           message: "Release PR closed without merging.",
                           state:   "closed",
                           cur_pr:  pr_info
  logger.info "Done."
end
