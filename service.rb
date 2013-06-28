require 'bundler'
Bundler.require

# configuration
CONFIG = YAML.load_file("./config/aws.yml")
AWS.config({
    access_key_id: CONFIG["AWS_ACCESS_KEY_ID"],
    secret_access_key: CONFIG["AWS_SECRET_ACCESS_KEY"]
})

sqs = AWS::SQS.new
stitch_queue        = sqs.queues.create("video-stitch")
stitch_ready_queue  = sqs.queues.create("video-stitch-ready")

queue.poll do |message|
  data = JSON.parse(message.body)

  video_id  = data["video_id"]
  parts     = data["parts"]
  output    = data["output"]

  Cacher.new.get(parts) do |files, tmpdir|
    begin
      stitched_file = Stitcher.stitch(files, "#{tmpdir}/#{output}")
      Uploader.upload_to_s3 stitched_file, output
      stitch_ready_queue.send_message({video_id: video_id})
    rescue
    end
  end
end
