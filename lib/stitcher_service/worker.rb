class Worker
  include Celluloid

  attr_reader :jobs_queue, :finish_queue, :error_queue, :bucket

  MAX_RETRIES = 10

  def initialize(input_queue, output_queue, error_queue, bucket)
    @jobs_queue   = input_queue
    @finish_queue = output_queue
    @error_queue = error_queue
    @bucket = bucket
    async.run
  end

  def run
    StitcherService.logger.info "start polling"
    jobs_queue.poll(attributes: [:all]) do |message|
      StitcherService.logger.info "recieve message"
      if message.approximate_receive_count > MAX_RETRIES
        error(message)
      else
        data = JSON.parse message.body
        StitcherService.logger.info message.body
        parts = data["parts"]
        output = data["output"]
        video_id = data["video_id"]
        reply = data["reply"]

        begin
          process(parts, output, video_id)
          notify_done("#{output}.mp4", video_id, reply)
        rescue => ex
          Honeybadger.notify(ex, parameters: data)
          raise
        end
      end
    end
  end

  private

  def error(message)
    error_queue.send_message(message.body)
  end

  def notify_done(output, video_id, reply)
    StitcherService.logger.info "complete: #{video_id}"
    finish_queue.send_message({output: output, video_id: video_id, reply: reply}.to_json)
  end

  def process(parts, output, video_id)
    StitcherService.logger.info "stitch video: #{video_id}"
    Cacher.new.get(parts) do |files, tmpdir|
      video = process_video(files, "#{output}.mp4", tmpdir)
      process_thumb(video, "#{output}-thumb.png", tmpdir)
    end
  end

  def process_video(files, output_file, tmpdir)
    local_output_file = "#{tmpdir}/#{File.basename output_file}"
    s3_output = bucket.objects[output_file]

    Movie.stitch(files.map(&:path), local_output_file)
    Uploader.upload_to_s3(local_output_file, s3_output)
    StitcherService.logger.info "output: #{s3_output.public_url}"

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

  def process_blurred_thumb(video, filename, tmpdir)
    #local output file
    local_output_file = "#{tmpdir}/#{File.basename filename}"

    #s3 output file
    s3_output = bucket.objects[filename]

    image = Movie.new(video).blurred_screengrab(local_output_file)
    Uploader.upload_to_s3(image, s3_output)

    image
  end
end
