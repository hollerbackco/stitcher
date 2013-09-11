require 'bundler'
Bundler.require

require './lib/stitcher_service'

desc "retry errored out videos"
task :retry, :environment do |t, args|
  config = YAML.load_file("./config/aws.yml")[args[:environment]]
  AWS.config(access_key_id: config["AWS_ACCESS_KEY_ID"],
             secret_access_key: config["AWS_SECRET_ACCESS_KEY"])

  sqs = AWS::SQS.new
  stitch_queue = sqs.queues.create(config["STITCH_QUEUE"])
  error_queue = sqs.queues.create(config["ERROR_QUEUE"])

  error_queue.poll do |message|
    stitch_queue.send_message(message.body)
  end
end
