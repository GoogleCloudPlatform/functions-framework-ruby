# frozen_string_literal: true

desc "Mark a release pull request as aborted"

long_desc \
  "This tool marks a release pull request as aborted. It is normally called" \
    " from a GitHub Actions workflow, but can be executed locally."

exactly_one desc: "Trigger Type" do
  flag :event_path, "--event-path=VAL" do
    desc "Provide the path to the pull request closed event"
    long_desc \
      "Set this to the path to the pull request closed event JSON file, if" \
        " invoked from a GitHub Actions workflow that was triggered by the" \
        " pull request being closed. If the target pull request was closed" \
        " without being merged, and has the release pending label, it will" \
        " be updated with the release aborted label. Otherwise, nothing is" \
        " done."
  end
  flag :given_pr_number, "--pr-number=VAL" do
    desc "Provide the pull request number"
    long_desc \
      "Set this to the number of the release pull request to abort. If the" \
        " given pull request has the release pending label, it will be" \
        " closed (if still open) and updated with the release aborted label." \
        " An error is reported if the given pull request does not have the" \
        " release pending label."
  end
end

include :exec, exit_on_nonzero_status: true
include :fileutils
include :terminal, styled: true

def run
  require "release_utils"

  cd context_directory
  utils = ReleaseUtils.new self

  if event_path
    handle_closed_event utils
  elsif given_pr_number
    handle_pr_number utils
  end
end

def handle_closed_event utils
  pull = ::JSON.parse(::File.read(event_path))["pull_request"]
  pr_number = pull["number"]

  if pull["merged_at"]
    logger.info "PR #{pr_number} is merged. Ignoring."
    return
  end
  if pull["labels"].all? { |label_info| label_info["name"] != utils.release_pending_label }
    logger.info "PR #{pr_number} does not have the pending label. Ignoring."
    return
  end

  abort_pr pr_number, utils, pull
end

def handle_pr_number utils
  pr_number = given_pr_number.to_i
  pull = utils.load_pr pr_number

  if pull["merged_at"]
    utils.error "PR #{pr_number} is already merged."
  end
  if pull["labels"].all? { |label_info| label_info["name"] != utils.release_pending_label }
    utils.error "PR #{pr_number} does not have the pending label."
  end

  abort_pr pr_number, utils, pull
end

def abort_pr pr_number, utils, pull
  logger.info "Updating release PR #{pr_number} to mark it as aborted."
  utils.update_release_pr pr_number,
                          label:   utils.release_aborted_label,
                          message: "Release PR closed without merging.",
                          state:   "closed",
                          cur_pr:  pull
  logger.info "Done."
end
