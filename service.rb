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
Honeybadger.context({
  environment: env
})

#work queues
sqs = AWS::SQS.new
stitch_queue = sqs.queues.create(CONFIG["STITCH_QUEUE"])
finish_queue = sqs.queues.create(CONFIG["FINISH_QUEUE"])

StitcherService.configure do |config|
  #error notifier
  sns = AWS::SNS.new
  error_sns = sns.topics.create(CONFIG["ERROR_SNS"])
  error_queue = sqs.queues.create(CONFIG["ERROR_SNS"])
  #error_sns.subscribe(error_queue)

  config.error_sns = error_sns
end

output_bucket = AWS::S3.new.buckets[CONFIG["BUCKET"]]

StitcherService.start(stitch_queue, finish_queue, output_bucket)
