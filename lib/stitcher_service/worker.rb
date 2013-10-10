class Worker
  include StitcherService::Util
  include Celluloid

  attr_reader :jobs_queue, :finish_queue, :bucket

  MAX_RETRIES = 10

  def initialize(input_queue, output_queue, bucket)
    @jobs_queue   = input_queue
    @finish_queue = output_queue
    @bucket = bucket
    async.run
  end

  def run
    logger.info "start polling"
    jobs_queue.poll(attributes: [:all]) do |message|
      logger.info "recieve message"
      if message.approximate_receive_count > MAX_RETRIES
        notify_error(message.body)
      else
        data = JSON.parse message.body
        logger.info message.body

        parts = data["parts"]
        output = data["output"]
        video_id = data["video_id"]
        reply = data["reply"]

        begin
          video_info = process(parts, output, video_id)
          data = data.merge("output" => "#{output}.mp4")
          data = data.merge("details" => video_info)
          notify_done(data)
        rescue => ex
          notify_error(message.body)
          Honeybadger.notify(ex, parameters: data)
          raise
        end
      end
    end
  end

  def process(parts, output, video_id)
    logger.info "stitch video: #{video_id}"
    Cacher.new.get(parts) do |files, tmpdir|
      video = process_video(files, "#{output}.mp4", tmpdir)
      process_thumb(video, "#{output}-thumb.png", tmpdir)
      video.info
    end
  end

  private

  def notify_done(data)
    logger.info "complete: #{data["video_id"]}"
    finish_queue.send_message(data.to_json)
  end

  def process_video(files, output_key, tmpdir)
    local_output_path = "#{tmpdir}/#{File.basename output_key}"

    movie = Movie.stitch(files.map(&:path), local_output_path)
    upload(movie.path, output_key)

    movie
  end

  def process_thumb(video, output_key, tmpdir)
    local_output_path = "#{tmpdir}/#{File.basename output_key}"

    image_path = video.screengrab(local_output_path)

    upload(image_path, output_key)

    image_path
  end

  def process_blurred_thumb(video, output_key, tmpdir)
    local_output_path = "#{tmpdir}/#{File.basename output_key}"

    image_path = Movie.new(video).blurred_screengrab(local_output_path)

    upload(image, output_key)

    image_path
  end

  def upload(local_path, key)
    uploader.upload_to_s3(local_path, key)
  end

  def uploader
    @uploader ||= Uploader.new(bucket)
  end
end
