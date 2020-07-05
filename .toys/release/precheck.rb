# frozen_string_literal: true

desc "Run release prechecks for the functions_framework gem"

include :terminal
include "release-tools"

required_arg :version

def run
  ::Dir.chdir context_directory

  puts "Running prechecks for releasing version #{version}...", :bold
  verify_git_clean
  verify_library_version version
  verify_changelog_content version
  verify_github_checks

  puts "SUCCESS", :green, :bold
end
