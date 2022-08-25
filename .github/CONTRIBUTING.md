# Contributing

Want to contribute? Great! This page gives you the essentials you need to know.

## Before you contribute

Before we can use your code, you must sign the
[Google Individual Contributor License Agreement]
(https://cla.developers.google.com/about/google-individual)
(CLA), which you can do online. The CLA is necessary mainly because you own the
copyright to your changes, even after your contribution becomes part of our
codebase, so we need your permission to use and distribute your code. We also
need to be sure of various other things—for instance that you'll tell us if you
know that your code infringes on other people's patents. You don't have to sign
the CLA until after you've submitted your code for review and a member has
approved it, but you must do it before we can put your code into our codebase.
Before you start working on a larger contribution, you should get in touch with
us first through the issue tracker with your idea so that we can help out and
possibly guide you. Coordinating up front makes it much easier to avoid
frustration later on.

Contributions made by corporations are covered by a different agreement than
the one above, the
[Software Grant and Corporate Contributor License Agreement]
(https://cla.developers.google.com/about/google-corporate).

## Development

### Useful tools

The Functions Framework runs on Ruby 2.6 or later. We recommend having a recent
version of Ruby for development and testing. The CI will test against all
supported versions of Ruby.

To run tests and other development processes, you should install the
[Toys](https://github.com/dazuma/toys) gem, which provides the task runner and
framework:

    gem install toys

You can then use Toys to run tests and other tasks. For example:

    toys rubocop
    toys test

You can also run the entire suite of CI tests using:

    toys ci

Toys handles bundling for you; you do not need to `bundle exec` when running
these tasks.

Rake is not used by this repository.

### Coding style

When modifying code, please adhere to the existing coding style. This is
enforced by Rubocop. See the [Rubocop config](.rubocop.yml) and the general
Google Ruby style config at https://github.com/googleapis/ruby-style, which is
based on "Seattle-style" Ruby.

It's a good idea to run Rubocop locally to check style before opening a pull
request:

    toys rubocop

### Tests

All contributions should be accompanied by tests. You can run the tests with:

    toys test

Test files live in the `test` directory and must match `test_*.rb`. Tests
_must_ use minitest as the test framework. This repository does not use rspec.
Any common tooling can be put in the `helper.rb` file.

We often use "spec-style" describe blocks rather than test classes, but we
prefer assertion syntax over expectation syntax.

The examples in the `examples` directory also have tests. These can be invoked
by cd-ing into the relevant example directory and running `toys test`.

Finally, this framework runs conformance tests that are defined in the
https://github.com/GoogleCloudPlatform/functions-framework-conformance repo.
To run the conformance tests:

    toys conformance

## Pull requests

All submissions, including submissions by project members, require review. We
use Github pull requests for this purpose.

### Commit messages

Commit messages _must_ follow
[Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/) style.
In short, you should prefix each commit message with a tag indicating the type
of change, usually `feat:`, `fix:`, `docs:`, or `tests:`, `refactor:`, or
`chore:`. The remainder of the commit message should be a description suitable
for inclusion in release notes. For example:

    fix: Fixed an error when setting a global to a Minitest::Mock

or

    feat: Support raw pubsub events sent by the pubsub emulator

If your change is trivial and should not be listed in release notes or trigger
a new release of the library, label it `chore:`.

It is very important that commit messages follow this style, because the
release tooling depends on it. If a commit message does not conform, the change
will not be listed in the release notes and may not trigger a library release.
