# Changelog

### 1.6.2 (2025-07-21)

#### Bug Fixes

* add api.deps.dev to allowlist for scorecard.yml ([#225](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/225)) 

### 1.6.1 (2025-07-19)

#### Bug Fixes

* update google-style to 1.31, fix linting issues ([#224](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/224)) 
* update workflow configs to drop ruby 3.0 ([#220](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/220)) 

### 1.6.0 (2025-02-07)

#### Features

* drop support for ruby &lt;3.0 ([#210](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/210)) 

### 1.5.1 (2025-02-06)

### Miscellaneous Chores

* release 1.5.1 ([#211](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/211)) 

### 1.5.0 (2025-01-03)

#### Features

* Support pidfile in CLI & Server (defaults to puma.pid) ([#178](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/178)) 

### 1.4.2 (2024-09-18)

#### Bug Fixes

* typo in cli help ([#196](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/196)) 
#### Documentation

* fix a broken link to the rack SPEC 

### 1.4.1 (2023-06-27)

#### Bug Fixes

* enable typed function compatibility with http signature ([#174](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/174)) 

### 1.4.0 (2023-06-16)

#### Features

* implement typed function signature ([#158](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/158)) 

### 1.3.0 (2023-04-05)

#### Features

* Support for Puma 6 and Rack 3

### 1.2.0 (2022-08-25)

* Update minimum Ruby version to 2.6
* Increase default max thread pool size to 16

### 1.1.0 (2022-01-18)

* Increase default max thread pool size to 8.
* Return 204 when a GET request is sent to an event function, to support health checks.
* Flush stdout and stderr streams at the end of each request.
* Format the error backtrace.

### 1.0.1 (2021-09-10)

* FIXED: Update legacy event conversion to set the correct types for firebase database events

### 1.0.0 (2021-07-07)

* Bumped the version to 1.0.
* Removed the "preview" notices for Google Cloud Functions since the Ruby runtime is now GA.

### v0.11.0 / 2021-06-28

* UPDATED: Update CloudEvents dependency to 0.5 to get fixes for JSON formatting cases
* FIXED: Updated Pub/Sub and Firebase event conversion logic to better align to Eventarc

### v0.10.0 / 2021-06-01

* ADDED: Support raw pubsub events sent by the pubsub emulator
* FIXED: Set proper response content-type charset when a function returns a string (plain text) or hash (JSON)
* FIXED: Properly handle conversion of non-ascii characters in legacy event strings

### v0.9.0 / 2021-03-18

* BREAKING CHANGE: Servers are configured as single-threaded in production by default, matching the current behavior of Google Cloud Functions.
* FIXED: Fixed conversion of Firebase events to CloudEvents to conform to the specs used by Cloud Functions and Cloud Run.
* FIXED: Fixed an error when reading a global set to a Minitest::Mock. This will make it easier to write tests that use mocks for global resources.

### v0.8.0 / 2021-03-02

* ADDED: Support for lazily-initialized globals

### v0.7.1 / 2021-01-26

* DOCS: Fixed several errors in the writing-functions doc samples
* DOCS: Updated documentation to note public release of GCF support 

### v0.7.0 / 2020-09-25

* Now requires Ruby 2.5 or later.
* BREAKING CHANGE: Renamed "context" hash to "globals" and made it read-only for normal functions.
* BREAKING CHANGE: Server config is no longer passed to startup blocks.
* ADDED: Provided a "logger" convenience method in the context object.
* ADDED: Globals can be set from startup blocks, which is useful for initializing shared resources.
* ADDED: Support for testing startup tasks in the Testing module.
* ADDED: Support for controlling logging in the Testing module.
* FIXED: Fixed crash introduced in 0.6.0 when a block didn't declare an expected argument.
* FIXED: Better support for running concurrent tests.
* DOCS: Expanded documentation on initialization, execution context, and shared resources.
* DEPRECATED: The functions-framework executable is deprecated. Use functions-framework-ruby instead.

### v0.6.0 / 2020-09-17

* ADDED: You can use the --version flag to print the framework version
* ADDED: You can use the --verify flag to verify that a given function is defined
* ADDED: You can now define blocks that are executed at server startup

### v0.5.2 / 2020-09-06

* FIXED: Use global $stderr rather than STDERR for logger 
* DOCS: Fix instructions for deployment to Google Cloud Functions 

### v0.5.1 / 2020-07-20

* Updated some documentation links. No functional changes.

### v0.5.0 / 2020-07-09

* Removed embedded CloudEvents classes and added the official CloudEvents SDK as a dependency. A `FunctionsFramework::CloudEvents` alias provides backward compatibility.

### v0.4.1 / 2020-07-08

* Fixed unsupported signal error on Windows.
* Fixed several edge case errors in legacy event conversion.
* Generated Content-Type headers now properly quote param values if needed.
* Minor documentation updates.

### v0.4.0 / 2020-06-29

* Dropped the legacy and largely unsupported `:event` function type. All event functions should be of type `:cloud_event`.
* Define the object context for function execution, and include an extensible context helper.
* Support for CloudEvents with specversion 0.3.
* CloudEvents now correct percent-encodes/decodes binary headers.
* CloudEvents now includes more robust RFC 2045 parsing of the Content-Type header.
* The CloudEventsError class now properly subclasses StandardError instead of RuntimeError.
* Removed redundant `_string` accessors from event classes since raw forms are already available via `[]`.
* A variety of corrections to event-related class documentation.

### v0.3.1 / 2020-06-27

* Fixed crash when using "return" directly in a function block.
* Added a more flexible request generation helper in the testing module.
* Fixed several typos in the documentation.

### v0.3.0 / 2020-06-26

* Updated the CloudEvent data format for converted pubsub events to conform to Cloud Run's conversion.

### v0.2.1 / 2020-06-25

* The `--signature-type` check recognizes the legacy `event` type for `:cloud_event` functions.

### v0.2.0 / 2020-06-24

Significant changes:

* Converts legacy GCF events and passes them to functions as CloudEvents.
* The executable is now named `functions-framework-ruby` to avoid collisions with functions frameworks for other languages.
* Deprecated the `event` function type. Use `cloud_event`.
* The CloudEvents implementation is now fully-featured and can encode as well as decode events.
* Wrote an expanded set of getting-started documentation.

Minor changes:

* `Testing.load_temporary` now caches loaded functions so they don't have to be reloaded for subsequent tests.
* The executable recognizes the `--signature-type` flag, and verifies that the type is correct.
* Error reporting is expanded and improved.
* Fixed a crash when a batch CloudEvent was received. (These are still not supported, and now result in a 400.)
* Renamed a few undocumented environment variables, and added support for a logging level environment variable. All CLI flags now have associated environment variables.
* Several fixes to the example code, and added a new Sinatra example.

### v0.1.1 / 2020-02-27

* Server returns 404 when receiving a /favicon.ico or /robots.txt request.
* Correct a rack constant name in Testing#make_post_request

### v0.1.0 / 2020-01-30

* Initial release
