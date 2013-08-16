require 'bundler'
Bundler.require

require './lib/stitcher_service'

$stdout.sync = true

env = ENV["SERVICE_ENV"] || "production"

# configuration
CONFIG = YAML.load_file("./config/aws.yml")[env]

AWS.config(access_key_id: CONFIG["AWS_ACCESS_KEY_ID"],
           secret_access_key: CONFIG["AWS_SECRET_ACCESS_KEY"])

Honeybadger.configure do |config|
  config.api_key = 'af50d456'
end

sqs = AWS::SQS.new
stitch_queue = sqs.queues.create(CONFIG["STITCH_QUEUE"])
finish_queue = sqs.queues.create(CONFIG["FINISH_QUEUE"])
error_queue = sqs.queues.create(CONFIG["ERROR_QUEUE"])
output_bucket = AWS::S3.new.buckets[CONFIG["BUCKET"]]

begin
  Honeybadger.context({
    environment: env
  })
  StitcherService.new(stitch_queue, finish_queue, error_queue, output_bucket).run
rescue => ex
  notify_honeybadger(ex)
  raise
end
