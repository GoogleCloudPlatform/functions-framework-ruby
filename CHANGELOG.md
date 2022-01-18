# Changelog

## [2.0.0](https://github.com/GoogleCloudPlatform/functions-framework-ruby/compare/functions_framework-v1.1.0...functions_framework/v2.0.0) (2022-01-18)


### ⚠ BREAKING CHANGES

* Servers are configured as single-threaded in production by default
* Rework globals mechanism to better support shared resources (#70)

### Features

* Accept --signature-type on the command line ([79c1af2](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/79c1af2c028c3e6740f464e2bb1993c42dd20295))
* Add a more flexible request generator in the testing module ([abdac4b](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/abdac4bb72fe581057d9004f22d1df0c57321a08))
* Add functions-framework-ruby executable ([6879a02](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/6879a029977db51dd7cc75caa040b0eda1dfbb4a))
* CloudEvents library supports multiple spec versions and encoding events ([#20](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/20)) ([83bfa4f](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/83bfa4ff8576e65621d99686e250be8d122e78fb))
* Expand and improve error reporting ([#19](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/19)) ([4446977](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/444697754e0f8c43dfd9378522866f5e8da37b7b))
* Include a Sinatra example ([94926ac](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/94926ac20dbf5bd6886e4e2f1c50d10644bef3fb))
* Increase default max thread pool size to 8 ([#125](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/125)) ([3e5da5e](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/3e5da5ebf4a186d71fe64a9e543d857a427fdae2))
* Provide an explicit execution context class ([ece1fbb](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/ece1fbb9d109cd0a494c4ea7b105ed0c8b96a0b4))
* Return 204 from GET requests to an event function, to support health checks ([#128](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/128)) ([f87ce40](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/f87ce40b2c55279a519650320d91142b6630a06c))
* Rework globals mechanism to better support shared resources ([#70](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/70)) ([30f9d4a](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/30f9d4a6f9fa70da4f58e0f23f8e8ee88e813f50))
* Support additional legacy event conversions ([#21](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/21)) ([9bc512d](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/9bc512deff48fbdf49cec0a6e3f11ed49baab968))
* Support CloudEvents 0.3 ([#35](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/35)) ([52fd489](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/52fd48922e5dbddf0101c2cb8bc21875af96e455))
* Support converting legacy events for pubsub, storage, and firestore ([789d473](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/789d473006934711c212d12e531cb904fa361442))
* Support for lazily-initialized globals ([a75ece5](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/a75ece593e1480bfabd49cf0a3cd0203bd39990a))
* Support raw pubsub events sent by the pubsub emulator ([#100](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/100)) ([71cb8c7](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/71cb8c7b355203939910734d4a34a71be49ba93e))
* Use official CloudEvents SDK library ([d0b0265](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/d0b02657eae92163a957471f3859bf86d2776969))
* You can now define blocks that are executed at server startup ([4665bf0](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/4665bf08fd8d104152c684cdeb5061a91b6a0960))
* You can use the --verify flag to verify that a given function is defined ([4e184a3](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/4e184a35d2b5a52065a10c9f2d4bd14947a1ea00))
* You can use the --version flag to print the framework version ([b0024b3](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/b0024b320b6b616c33c2d1690ca0883f806422bf))


### Bug Fixes

* Allow return statements in functions ([ead9a2d](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/ead9a2d1674a41b84e69a4945a0641026b1d37eb))
* Cache definitions loaded using Testing.load_temporary ([dafbf46](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/dafbf4624ebd7e6e2b19292aa7d2ba09c8af1bd2))
* CloudEvents content-type parsing now fully implements RFC 2045 ([3fcc146](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/3fcc146c4a5d59e72f6146073adebdd532faeece))
* Conformance fixes for Firebase to CloudEvent conversions ([#89](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/89)) ([fcdb6a8](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/fcdb6a8832e0fa501b5f3d636ca099bf7c6445ce))
* Content-Type canonical strings are properly quoted ([9bb7a9a](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/9bb7a9a1e6565e06303873858935bf18b735f4b4))
* correct a rack constant name in Testing#make_post_request ([8984492](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/89844927047f27eb5244274f35ad2881317178a1))
* Correctly percent-encode CloudEvents binary headers ([d906c26](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/d906c2667ebafead069cf955772d2dd3d0d35dfc))
* Deprecate two-argument event function signature ([d0771de](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/d0771de0618fd4add8d184602c72965e8f448b22))
* Fixed an error when setting a global to a Minitest::Mock ([884cdfe](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/884cdfecc5ba9cce12059279383a8725e41006a3))
* Flush stdout and stderr streams at the end of each request ([#126](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/126)) ([1b6847d](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/1b6847dc87c7324b0807ea9c4340fb50a2be39b8))
* Format the error backtrace ([a23620f](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/a23620f037d86733f8d2eb7fbb2d25fde1c9a194))
* Handle some legacy event conversion edge cases ([d1e7d49](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/d1e7d49e68e2d298d530949626f36b08faa33c6b))
* Improve compatibility with Windows and JRuby ([2dde4da](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/2dde4da0aa4a82776100395ce712acb45effb5e4))
* Loosen firebasedatabase domain restriction in legacy event conversion ([#109](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/109)) ([2a4e45d](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/2a4e45d8996ba5d113afe63723430c63aa10ff86))
* Properly handle conversion of non-ascii characters in legacy event strings ([8d5c419](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/8d5c41985ed9d25a863a0e7a13bdf77e514b3ffc))
* Properly handle conversion of non-ascii characters in legacy event strings ([#99](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/99)) ([b2b42cb](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/b2b42cbf73ed75abcfaf71e12785cdf23bcede28))
* Rename echo sample functions to conform to GCF restrictions ([#22](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/22)) ([1a641dc](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/1a641dc45b67c7639bc61b614e0ff883048ef407))
* return 404 on favicon and robots paths ([ae3bbf6](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/ae3bbf678b4c6cb7c23e91ab9272ae6d04aefbac))
* Servers are configured as single-threaded in production by default ([609d32e](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/609d32e6220843ca551a3904939f508c3607c72f))
* Set correct CloudEvent subject when converting a Firebase Auth event ([e9fcd0f](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/e9fcd0f056c0d9bc1d65971494f654fc2e343757))
* Set proper response content-type charset ([#98](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/98)) ([77784ce](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/77784ce9fe11d22fa1f22dc7406ec1be58724acc))
* Signature type check succeeds when given the legacy event type ([f6ac2f6](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/f6ac2f694266177755107d6ce2f2475911581b05))
* Update CloudEvents dependency ([#108](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/108)) ([95703e7](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/95703e7b7b9efbbd2055d5086ed3b78a02ca96d0))
* Update legacy event conversion to set the correct types for firebase database events ([a0e4df5](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/a0e4df5fa0a6364032bdf0d036065a3bc9887395))
* Update pubsub CloudEvent data conversion to match Cloud Run ([969bc2e](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/969bc2e937140be2694c468924c9fa5081b260b1))
* Updated the Pub/Sub event conversion logic to better align to Eventarc ([#105](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/105)) ([6686ce3](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/6686ce3fd90f029da7c6cecdb93672bd5dece13f))
* Use global $stderr rather than STDERR for logger ([#59](https://github.com/GoogleCloudPlatform/functions-framework-ruby/issues/59)) ([7452d19](https://github.com/GoogleCloudPlatform/functions-framework-ruby/commit/7452d19744b14a0d08e6c248ce0fad3f0b6e7038))

## 1.0.1 (2021-09-10)

* FIXED: Update legacy event conversion to set the correct types for firebase database events

## 1.0.0 (2021-07-07)

* Bumped the version to 1.0.
* Removed the "preview" notices for Google Cloud Functions since the Ruby runtime is now GA.

## v0.11.0 / 2021-06-28

* UPDATED: Update CloudEvents dependency to 0.5 to get fixes for JSON formatting cases
* FIXED: Updated Pub/Sub and Firebase event conversion logic to better align to Eventarc

## v0.10.0 / 2021-06-01

* ADDED: Support raw pubsub events sent by the pubsub emulator
* FIXED: Set proper response content-type charset when a function returns a string (plain text) or hash (JSON)
* FIXED: Properly handle conversion of non-ascii characters in legacy event strings

## v0.9.0 / 2021-03-18

* BREAKING CHANGE: Servers are configured as single-threaded in production by default, matching the current behavior of Google Cloud Functions.
* FIXED: Fixed conversion of Firebase events to CloudEvents to conform to the specs used by Cloud Functions and Cloud Run.
* FIXED: Fixed an error when reading a global set to a Minitest::Mock. This will make it easier to write tests that use mocks for global resources.

## v0.8.0 / 2021-03-02

* ADDED: Support for lazily-initialized globals

## v0.7.1 / 2021-01-26

* DOCS: Fixed several errors in the writing-functions doc samples
* DOCS: Updated documentation to note public release of GCF support 

## v0.7.0 / 2020-09-25

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

## v0.6.0 / 2020-09-17

* ADDED: You can use the --version flag to print the framework version
* ADDED: You can use the --verify flag to verify that a given function is defined
* ADDED: You can now define blocks that are executed at server startup

## v0.5.2 / 2020-09-06

* FIXED: Use global $stderr rather than STDERR for logger 
* DOCS: Fix instructions for deployment to Google Cloud Functions 

## v0.5.1 / 2020-07-20

* Updated some documentation links. No functional changes.

## v0.5.0 / 2020-07-09

* Removed embedded CloudEvents classes and added the official CloudEvents SDK as a dependency. A `FunctionsFramework::CloudEvents` alias provides backward compatibility.

## v0.4.1 / 2020-07-08

* Fixed unsupported signal error on Windows.
* Fixed several edge case errors in legacy event conversion.
* Generated Content-Type headers now properly quote param values if needed.
* Minor documentation updates.

## v0.4.0 / 2020-06-29

* Dropped the legacy and largely unsupported `:event` function type. All event functions should be of type `:cloud_event`.
* Define the object context for function execution, and include an extensible context helper.
* Support for CloudEvents with specversion 0.3.
* CloudEvents now correct percent-encodes/decodes binary headers.
* CloudEvents now includes more robust RFC 2045 parsing of the Content-Type header.
* The CloudEventsError class now properly subclasses StandardError instead of RuntimeError.
* Removed redundant `_string` accessors from event classes since raw forms are already available via `[]`.
* A variety of corrections to event-related class documentation.

## v0.3.1 / 2020-06-27

* Fixed crash when using "return" directly in a function block.
* Added a more flexible request generation helper in the testing module.
* Fixed several typos in the documentation.

## v0.3.0 / 2020-06-26

* Updated the CloudEvent data format for converted pubsub events to conform to Cloud Run's conversion.

## v0.2.1 / 2020-06-25

* The `--signature-type` check recognizes the legacy `event` type for `:cloud_event` functions.

## v0.2.0 / 2020-06-24

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

## v0.1.1 / 2020-02-27

* Server returns 404 when receiving a /favicon.ico or /robots.txt request.
* Correct a rack constant name in Testing#make_post_request

## v0.1.0 / 2020-01-30

* Initial release
