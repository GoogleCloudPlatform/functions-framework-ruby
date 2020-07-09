<!--
# @title Functions Framework Overview
-->

# Functions Framework for Ruby

The Functions Framework is an open source framework for writing lightweight,
portable Ruby functions that run in a serverless environment. Functions written
to this Framework will run in many different environments, including:

 *  [Google Cloud Functions](https://cloud.google.com/functions) *(in preview)*
 *  [Cloud Run or Cloud Run for Anthos](https://cloud.google.com/run)
 *  Any other [Knative](https://github.com/knative)-based environment
 *  Your local development machine

The framework allows you to go from:

```ruby
FunctionsFramework.http("hello") do |request|
  "Hello, world!\n"
end
```

To:

```sh
curl http://my-url
# Output: Hello, world!
```

Running on a fully-managed or self-managed serverless environment, without
requiring an HTTP server or complicated request handling logic.

## Features

 *  Define named functions using normal Ruby constructs.
 *  Invoke functions in response to requests.
 *  Automatically unmarshal events conforming to the
    [CloudEvents](https://cloudevents.io) spec.
 *  Automatically convert most legacy events from Google Cloud services such
    as Cloud Pub/Sub and Cloud Storage, to CloudEvents.
 *  Spin up a local development server for quick testing.
 *  Integrate with standard Ruby libraries such as Rack and Minitest.
 *  Portable between serverless platforms.
 *  Supports all non-end-of-life versions of Ruby.

## Supported Ruby versions

This library is supported on Ruby 2.4+.

Google provides official support for Ruby versions that are actively supported
by Ruby Core—that is, Ruby versions that are either in normal maintenance or
in security maintenance, and not end of life. Currently, this means Ruby 2.4
and later. Older versions of Ruby _may_ still work, but are unsupported and not
recommended. See https://www.ruby-lang.org/en/downloads/branches/ for details
about the Ruby support schedule.

## Quickstart

Here is how to run a Hello World function on your local machine.

Create a `Gemfile` listing the Functions Framework as a dependency:

```ruby
# Gemfile
source "https://rubygems.org"
gem "functions_framework", "~> 0.5"
```

Create a file called `app.rb` and include the following code. This defines a
simple function called "hello".

```ruby
# app.rb
require "functions_framework"

FunctionsFramework.http("hello") do |request|
  "Hello, world!\n"
end
```

Install the bundle, and start the framework. This spins up a local web server
running your "hello" function:

```sh
bundle install
# ...installs the functions_framework gem and other dependencies
bundle exec functions-framework-ruby --target hello
# ...starts the functions server in the foreground
```

In a separate shell, you can send requests to this function using curl:

```sh
curl http://localhost:8080
# Output: Hello, world!
```

Stop the server with `CTRL+C`.

## Documentation

These guides provide additional getting-started information.

 *  **{file:docs/writing-functions.md Writing Functions}** :
    How to write functions that respond to HTTP requests, industry-standard
    [CloudEvents](https://cloudevents.io), as well as events sent from Google
    Cloud services such as [Pub/Sub](https://cloud.google.com/pubsub) and
    [Storage](https://cloud.google.com/storage).
 *  **{file:docs/testing-functions.md Testing Functions}** :
    How to use the testing features of the Functions Framework to write local
    unit tests for your functions using standard Ruby testing frameworks such
    as [Minitest](https://github.com/seattlerb/minitest) and
    [RSpec](https://rspec.info/).
 *  **{file:docs/running-a-functions-server.md Running a Functions Server}** :
    How to use the `functions-framework-ruby` executable to run a local
    functions server.
 *  **{file:docs/deploying-functions.md Deploying Functions}** :
    How to deploy functions to
    [Google Cloud Functions](https://cloud.google.com/functions) or
    [Google Cloud Run](https://cloud.google.com/run).

The library reference documentation can be found at:
https://rubydoc.info/gems/functions_framework

Additional examples are available in the GitHub repository:
https://github.com/GoogleCloudPlatform/functions-framework-ruby/blob/master/examples/

## Development

The source for the Ruby Functions Framework is available on GitHub at
https://github.com/GoogleCloudPlatform/functions-framework-ruby. For more
information on the Functions Framework contract implemented by this framework,
as well as links to Functions Frameworks for other languages, see
https://github.com/GoogleCloudPlatform/functions-framework.

The Functions Framework is open source under the Apache 2.0 license.
Contributions are welcome. Please see the contributing guide at
https://github.com/GoogleCloudPlatform/functions-framework-ruby/blob/master/.github/CONTRIBUTING.md.

Report issues at
https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues.
