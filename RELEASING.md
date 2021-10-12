# Releasing

Releases are performed using tooling developed by Google's GitHub Automation
team, and are partially automated, but can be controlled by maintainers.

## The automated release pipeline

Whenever a commit is pushed to the main branch with a
[Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/) message,
the automated release pipeline will trigger.

### Release pull requests

The [release-please](https://github.com/googleapis/release-please) bot watches
for commits that indicate a semantic change, normally either `feat:` or `fix:`,
or any commit that includes a breaking change. When new commits are pushed,
release-please will propose a new release whose version is based on the semver
implication of the change: a patch release for a `fix:`, a minor release for a
`feat:`, or a major release for a breaking change. This will appear in the form
of a pull request, which will include the proposed new version, and a changelog
entry.

A maintainer can either:

* Close the pull request to defer the release until more changes have been
  committed.
* Accept the release by merging the pull request, possibly after modifying the
  changelog.

Do NOT modify the version in the pull request. If you want to release a
different version, see the next section on proposing releases manually.

When merging a release pull request, make sure the `autorelease: pending` label
remains applied. This is important for correct operation of the rest of the
release pipeline.

### Release scripts

After a release pull request is merged, another bot will trigger the rest of
the release pipeline. This bot runs every 15 minutes, so this process may be
delayed a few minutes. Once it runs, it will do the following automatically:

* Tag the release and create a GitHub release. This takes place in a kokoro
  (internal Google) job. Once finished, it will switch the tag from
  `autorelease: pending` to `autorelease: tagged`. If it seems to be
  malfunctioning, you can find logs on the internal fusion dashboard under the
  job `cloud-devrel/client-libraries/autorelease/tag`.
* Build and push the gem to Rubygems, and build and push the documentation to
  googleapis.dev. This takes place in a second kokoro job. Once finished, it
  will switch the tag from `autorelease: tagged` to `autorelease: published`.
  If this job seems to be malfunctioning, find the logs under the kokoro job
  `cloud-devrel/ruby/functions-framework-ruby/release`.

## Manually proposing a release

If you want to propose a release out-of-band or customize the version number to
use, you can use a command line tool to create a release pull request.

### Prerequisites

You need to install:

* git version 2.22 or later
* The gh cli (https://cli.github.com/)
* The release-please npm module
* The toys rubygem

### Running the release proposal script

Once the prerequisites are installed, run:

    toys release please functions_framework:1.2.3

(Replace `1.2.3` with the version to release.)

This will open an appropriate release pull request. Then you can merge it
(possibly after modifying the changelog) and the release pipeline will proceed
as described above.
