class StitcherService
  attr_reader :jobs_queue, :finish_queue, :bucket

  # receives to queues
  def initialize(jobs_queue, output_queue, bucket)
    @jobs_queue   = jobs_queue
    @finish_queue = output_queue
    @bucket = bucket
  end

  def run
    jobs_queue.poll do |message|
      data = JSON.parse(message.body)

      parts = data["parts"]
      output = data["output"]
      video_id  = data["video_id"]

      stitch(parts, output, video_id)
    end
  end

  def stitch(parts, output, video_id)
    Cacher.new.get(parts) do |files, tmpdir|
      s3_output = bucket.objects[output]

      local_output = "#{tmpdir}/#{output}"
      Stitcher.stitch(files.map(&:path), local_output)
      Uploader.upload_to_s3(local_output, s3_output)
      notify_done(output, video_id)
    end
  rescue
    raise
  end

  private

  def notify_done(output, video_id)
    finish_queue.send_message({output: output, video_id: video_id}.to_json)
  end
end
