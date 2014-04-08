class Worker
  include StitcherService::Util
  include Celluloid

  attr_reader :jobs_queue, :finish_queue, :bucket

  MAX_RETRIES = 10

  def initialize(input_queue, output_queue, bucket)
    @jobs_queue = input_queue
    @finish_queue = output_queue
    @bucket = bucket
    async.run
  end

  def run
    logger.info "start polling"
    jobs_queue.poll(attributes: [:all]) do |message|
      logger.info "recieve message"
      if message.approximate_receive_count != nil && message.approximate_receive_count > MAX_RETRIES
        notify_error(message.body)
      else
        data = JSON.parse message.body
        logger.info message.body

        parts = data["parts"]
        output = data["output"]
        video_id = data["video_id"]
        reply = data["reply"]
        backoff = data["failure_backoff"]

        if (backoff != nil)
          logger.info backoff.to_s
        end

        begin
          #the whole processing shouldn't take longer than 25 seconds
          video_info = process(parts, output, video_id)
          data = data.merge("output" => "#{output}.mp4")
          data = data.merge("details" => video_info)
          notify_done(data)
        rescue Movie::TimeoutException => ex
          logger.info "Timeout!: #{ex.message}"
          #back off a couple of times
          backoff = data["long_running_backoff"]
          if (backoff == nil)
            data["long_running_backoff"] = 2
            jobs_queue.send_message(data.to_json, {:delay_seconds => data["long_running_backoff"]})

          elsif backoff < 9
            data["long_running_backoff"] = backoff * 2
            jobs_queue.send_message(data.to_json, {:delay_seconds => data["long_running_backoff"]})

          else
            logger.error "video process took too long"
            notify_error({body: message.body, message: "ffmpeg took to long to process video"}.to_json)
          end
        rescue Exception => ex
          logger.error ex.message
          if (backoff == nil)
            data["failure_backoff"] = 1
            jobs_queue.send_message(data.to_json, {:delay_seconds => data["failure_backoff"]})

          elsif (backoff < 128) #make sure it's less than 128
            data["failure_backoff"] = backoff * 2;
            jobs_queue.send_message(data.to_json, {:delay_seconds => data["failure_backoff"]})
          else
            logger.error "couldn't process video"
            notify_error({body: message.body, message: ex}.to_json)
            Honeybadger.notify(ex, parameters: data)
          end
        end


      end
    end
  end

  def process(parts, output, video_id)
    logger.info "stitch video: #{video_id}"

    #TODO: upload files in parallel

    #shouldn't take longer than 25s
    Cacher.new.get(parts) do |files, tmpdir|
      video = process_video(files, "#{output}.mp4", tmpdir)
      process_thumb(video, "#{output}-thumb.png", tmpdir)
      process_gif(video, "#{output}.gif", tmpdir)
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

  #create a gif and upload it
  def process_gif(video, output_key, tmpdir)
    local_output_path = "#{tmpdir}/#{File.basename output_key}"

    video.gif(local_output_path)

    upload(local_output_path, output_key)

    local_output_path
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
