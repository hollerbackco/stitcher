require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe StitcherService do
  before do
    sqs = AWS::SQS.new
    @stitch_queue = sqs.queues.create("video-stitch-test-#{SecureRandom.hex(3)}")
    @finish_queue = sqs.queues.create("video-stitch-ready-tester-#{SecureRandom.hex(3)}")
    @error_queue = sqs.queues.create("video-stitch-error-tester-#{SecureRandom.hex(3)}")
    @output_bucket = AWS::S3.new.buckets.create("hollerback-app-test-#{SecureRandom.hex(3)}")
    @service = StitcherService.new(@stitch_queue, @finish_queue, @error_queue, @output_bucket)
  end

  after do
    @stitch_queue.delete
    @finish_queue.delete
    @error_queue.delete
    @output_bucket.clear!
    @output_bucket.delete
  end

  it "should stitch a file from a list of urls" do
    parts = [
      "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
      "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
    ]
    output = "test.mp4"
    video_id = 0

    @service.process(parts, output, video_id)
  end
end
