$:.unshift File.dirname(__FILE__)

require 'stitcher_service/movie'
require 'stitcher_service/cacher'
require 'stitcher_service/uploader'

class StitcherService
  attr_reader :jobs_queue, :finish_queue, :bucket

  def self.logger
    @logger ||= self.create_logger
  end

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

      process(parts, output, video_id)
    end
  end

  def process(parts, output, video_id)
    Cacher.new.get(parts) do |files, tmpdir|
      video = process_video(files, "#{output}.mp4", tmpdir)
      process_blurred_thumb(video, "#{output}-thumb.png", tmpdir)
      #process_blurred_thumb(video, "#{output}-thumb-blurred.png", tmpdir)
      notify_done("#{output}.mp4", video_id)
    end
  rescue
    raise
  end

  private

  def self.create_logger
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger
  end

  def notify_done(output, video_id)
    finish_queue.send_message({output: output, video_id: video_id}.to_json)
  end

  def process_video(files, output_file, tmpdir)
    #local output file
    local_output_file = "#{tmpdir}/#{File.basename output_file}"
    #s3 output file
    s3_output = bucket.objects[output_file]

    Movie.stitch(files.map(&:path), local_output_file)
    Uploader.upload_to_s3(local_output_file, s3_output)

    local_output_file
  end

  def process_thumb(video, filename, tmpdir)
    #local output file
    local_output_file = "#{tmpdir}/#{File.basename filename}"

    #s3 output file
    s3_output = bucket.objects[filename]

    image = Movie.new(video).screengrab(local_output_file)
    Uploader.upload_to_s3(image, s3_output)

    image
  end

  def process_thumb_blurred(video, filename, tmpdir)
    #local output file
    local_output_file = "#{tmpdir}/#{File.basename filename}"

    #s3 output file
    s3_output = bucket.objects[filename]

    image = Movie.new(video).blurred_screengrab(local_output_file)
    Uploader.upload_to_s3(image, s3_output)

    image
  end
end
