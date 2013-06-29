require 'bundler'
Dir[File.dirname(__FILE__) + "/lib/**/*.rb"].each {|f| require f}
Bundler.require

# configuration
CONFIG = YAML.load_file("./config/aws.yml")

AWS.config(access_key_id: CONFIG["AWS_ACCESS_KEY_ID"],
           secret_access_key: CONFIG["AWS_SECRET_ACCESS_KEY"])

sqs = AWS::SQS.new
stitch_queue = sqs.queues.create(CONFIG["STITCH_QUEUE"])
finish_queue = sqs.queues.create(CONFIG["FINISH_QUEUE"])
output_bucket = AWS::S3.new.buckets[CONFIG["BUCKET"]]

StitcherService.new(stitch_queue, finish_queue, output_bucket).run
