<!--
# @title Testing Functions
-->

# Testing Functions

This guide covers writing unit tests for functions using the Functions Framework
for Ruby. For more information about the Framework, see the
{file:docs/overview.md Overview Guide}.

## Overview of function testing

One of the benefits of the functions-as-a-service paradigm is that functions are
easy to test. In many cases, you can simply call a function with input, and test
the output. You do not need to set up (or mock) an actual server.

The Functions Framework provides utility methods that streamline the process of
setting up functions and the environment for testing, constructing input
parameters, and interpreting results. These are available in the
[Testing module](https://rubydoc.info/gems/functions_framework/FunctionsFramework/Testing).
Generally, you can include this module in your Minitest test class or RSpec
describe block.

```ruby
require "minitest/autorun"
require "functions_framework/testing"

class MyTest < Minitest::Test
  include FunctionsFramework::Testing
  # define tests...
end
```

```ruby
require "rspec"
require "functions_framework/testing"

describe "My functions" do
  include FunctionsFramework::Testing
  # define examples...
end
```

## Loading functions for testing

To test a function, you'll need to load the Ruby file that defines the function,
and run the function to test its results. The Testing module provides a method
[load_temporary](https://rubydoc.info/gems/functions_framework/FunctionsFramework/Testing#load_temporary-instance_method),
which loads a Ruby file, defining functions but only for the scope of your test.
This allows your test to coexist with tests for other functions, even functions
with the same name from a different Ruby file.

```ruby
require "minitest/autorun"
require "functions_framework/testing"

class MyTest < Minitest::Test
  include FunctionsFramework::Testing

  def test_a_function
    load_temporary "foo.rb" do
      # Test a function defined in foo.rb
    end
  end

  def test_another_function
    load_temporary "bar.rb" do
      # Test a function defined in bar.rb
    end
  end
end
```

When running a test suite, you'll typically need to load all the Ruby files
that define your functions. While `load_temporary` can ensure that the function
definitions do not conflict, it cannot do the same for classes, methods, and
other Ruby constructs. So, for testability, it is generally good practice to
include only functions in one of these files. If you need to write supporting
helper methods, classes, constants, or other code, include them in separate
ruby files that you `require`.

## Testing HTTP functions

Testing an HTTP function is generally as simple as generating a request, calling
the function, and asserting against the response.

The input to an HTTP function is a
[Rack::Request](https://rubydoc.info/gems/rack/Rack/Request) object. It is
usually not hard to construct one of these objects, but the `Testing` module
includes helper methods that you can use to create simple requests for many
basic cases.

When you have constructed an input request, use
[call_http](https://rubydoc.info/gems/functions_framework/FunctionsFramework/Testing#call_http-instance_method)
to call a named function, passing the request object. This method returns a
[Rack::Response](https://rubydoc.info/gems/rack/Rack/Response) that you can
assert against.

```ruby
require "minitest/autorun"
require "functions_framework/testing"

class MyTest < Minitest::Test
  include FunctionsFramework::Testing

  def test_http_function
    load_temporary "app.rb" do
      request = make_post_request "https://example.com/foo", "{\"name\":\"Ruby\"}",
                                  ["Content-Type: application/json"]
      response = call_http "my_function", request
      assert_equal 200, response.status
      assert_equal "Hello, Ruby!", response.body.join
    end
  end
end
```

If the function raises an exception, the exception will be converted to a 500
response object. So if you are testing an error case, you should still check the
response object rather than looking for a raised exception.

```ruby
require "minitest/autorun"
require "functions_framework/testing"

class MyTest < Minitest::Test
  include FunctionsFramework::Testing

  def test_erroring_http_function
    load_temporary "app.rb" do
      request = make_post_request "https://example.com/foo", "{\"name\":\"Ruby\"}",
                                  ["Content-Type: application/json"]
      response = call_http "error_function", request
      assert_equal 500, response.status
      assert_match(/ArgumentError/, response.body.join)
    end
  end
end
```

## Testing CloudEvent functions

Testing a CloudEvent function works similarly. The `Testing` module provides
methods to help construct example CloudEvent objects, which can then be passed
to the method
[call_event](https://rubydoc.info/gems/functions_framework/FunctionsFramework/Testing#call_event-instance_method).

Unlike HTTP functions, event functions do not have a return value. Instead, you
will need to test side effects. A common approach is to test logs by capturing
the standard error output.

```ruby
require "minitest/autorun"
require "functions_framework/testing"

class MyTest < Minitest::Test
  include FunctionsFramework::Testing

  def test_event_function
    load_temporary "app.rb" do
      event = make_cloud_event "Hello, world!", type: "my-type"
      _out, err = capture_subprocess_io do
        call_event "my_function", event
      end
      assert_match(/Received: "Hello, world!"/, err)
    end
  end
end
```
