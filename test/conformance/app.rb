require "json"
require "functions_framework"
require "cloud_events/json_format"

OUTPUT_FILE = "function_output.json"

FunctionsFramework.http "http_func" do |request|
  File.write OUTPUT_FILE, request.body.read
  "ok"
end

FunctionsFramework.cloud_event "cloudevent_func" do |event|
  # The conformance tests expect that JSON data is marshaled as a JSON object,
  # not a string. If the data is JSON but is represented as a string, parse it
  # so that later it's marshaled as expected.
  if event.data_content_type == CloudEvents::ContentType.new("application/json") && event.data.instance_of?(String)
    event = event.with(data: JSON.parse(event.data))
  end

  json_format = CloudEvents::JsonFormat.new
  File.write OUTPUT_FILE, json_format.encode(event)
end
