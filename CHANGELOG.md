# Changelog

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
