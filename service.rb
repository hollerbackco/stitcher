require 'bundler'
require 'dotenv'
Bundler.require

ENV['LOG_FILE']='stitcher.log'
Dotenv.load('./local.env') if File.exist?('./local.env')

require './lib/stitcher_service'

$stdout.sync = true

env = ENV["SERVICE_ENV"] || "production"

p "environment: #{env}"

# configuration
CONFIG = YAML.load_file("./config/aws.yml")[env]

if (env == 'local')
  AWS.config(
      :use_ssl => false,
      :sqs_endpoint => "localhost",
      :sqs_port => 4568,
      access_key_id: CONFIG["AWS_ACCESS_KEY_ID"],
      secret_access_key: CONFIG["AWS_SECRET_ACCESS_KEY"])
else
  AWS.config(access_key_id: CONFIG["AWS_ACCESS_KEY_ID"],
             secret_access_key: CONFIG["AWS_SECRET_ACCESS_KEY"])
end


Honeybadger.configure do |config|
  config.api_key = 'af50d456'
end
Honeybadger.context({
                        environment: env
                    })

sqs = AWS::SQS.new

StitcherService.configure do |config|
  #error notifier
  sns = AWS::SNS.new
  error_sns = sns.topics.create(CONFIG["ERROR_SNS"])
  error_queue = sqs.queues.create(CONFIG["ERROR_SNS"])
  #error_sns.subscribe(error_queue)

  config.error_sns = error_sns
end

output_bucket = AWS::S3.new.buckets[CONFIG["BUCKET"]]


stitch_queue = nil
finish_queue = nil

queue_collection = sqs.queues
queue_collection.each do |queue|
  p queue.url
end


#work queues
if (env != 'local')
  stitch_queue = sqs.queues.create(CONFIG["STITCH_QUEUE"])
  finish_queue = sqs.queues.create(CONFIG["FINISH_QUEUE"])
else

  begin
    stitch_queue = sqs.queues.named(CONFIG["STITCH_QUEUE"])
  rescue Exception => e
    stitch_queue = sqs.queues.create(CONFIG["STITCH_QUEUE"])
  end

  begin
    finish_queue = sqs.queues.named(CONFIG["FINISH_QUEUE"])
  rescue Exception => e
    finish_queue = sqs.queues.create(CONFIG["FINISH_QUEUE"])
  end
end

StitcherService.start(stitch_queue, finish_queue, output_bucket)
