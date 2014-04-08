require 'timeout'

class Movie
  include StitcherService::Util

  class TimeoutException < Exception
    def initialize(message)
      @message = message
    end

    def to_s
      @message
    end
  end

  def self.execute_process(command, timeout=0)
    logger.info "timeout: #{timeout}"
    if (timeout < 0)
      raise TimeoutException.new("Timeout: #{command} pre-execution")
    end

    pid = Process.spawn(command)

    begin
      Timeout.timeout(timeout) do
        logger.info 'waiting for the process to end'
        Process.wait(pid)
        logger.info 'process finished in time'
      end
    rescue Timeout::Error
      logger.info "Timeout: '#{command}' process not finished in time, killing it."
      Process.kill('TERM', pid)
      raise TimeoutException.new("Timeout: #{command} took too long to execute")
    end
  end

  def self.stitch(files=[], output_file)
    raise "no files were included in the stitch request" if files.empty?

    end_time = Time.now + 25 #need to exeucte this within 25s

    tmpdir = File.dirname(output_file)
    inter_file = File.join(tmpdir, "inter.mpg")

    # check rotation
    movie = Movie.new(files.first)
    #rotation = movie.rotation

    # transmux to mpg container format
    mpgs = files.map do |file|
      movie = Movie.new(file)

      if movie.valid?
        mpg_movie = movie.mpgify(end_time - Time.now)
      else
        if movie.duration < 0.3
          logger.error "video part was too short: #{files.index(file)} - #{movie.path}"
        end
        logger.error "[ERROR] invalid video part number: #{files.index(file)} - #{movie.path}"
        nil
      end
    end.compact
    raise "no valid files in the stitch request" if mpgs.empty?

    # build concatenate command
    command = "cat "
    mpgs.each do |movie|
      command << "#{movie.path} "
    end
    command << " > #{inter_file}"
    logger.info "concatenate file: #{command}"

    Movie.execute_process(command, end_time - Time.now)

    # create the final file
    command = "ffmpeg -i #{inter_file}"
    #if rotation
    #command << " -metadata:s:v:0 rotate=#{rotation}"
    #end
    command << " -qscale:v 4 #{output_file}"
    Movie.execute_process(command, end_time - Time.now)

    if (ENV["SERVICE_ENV"] != 'local')
      #interleave
      command = "MP4Box -inter 1000 #{output_file}"
      Movie.execute_process(command, end_time - Time.now)
    end

    self.new(output_file)
  end

  attr_accessor :path

  def initialize(filepath)
    @path = filepath
  end

  def mpgify(timeout)
    new_filepath = "#{self.path}.mpg"
    mpg_command = "ffmpeg -i #{self.path} -y -qscale:v 1 -r 24 "
    if transpose
      mpg_command << "-vf \"transpose=#{transpose}\" "
    end
    mpg_command << new_filepath
    p mpg_command

    Movie.execute_process(mpg_command, timeout)

    Movie.new(new_filepath)
  end

  def valid?
    ffmpeg_video.valid?
  end

  def duration
    ffmpeg_video.duration
  end

  def rotation
    command = "ffprobe -v quiet -print_format json -show_streams #{path}"
    Open3.popen3(command) do |stdin, stdout, stderr|
      data = JSON.parse(stdout.read)["streams"]
      if data
        data = data.map { |stream| stream["tags"]["rotate"] }.compact
        if data.any?
          data.first
        else
          nil
        end
      else
        nil
      end
    end
  end

  def transpose
    case rotation
      when "90"
        1
      when "270"
        2
      else
        nil
    end
  end

  def info
    {
        size: ffmpeg_video.size,
        resolution: [ffmpeg_video.width, ffmpeg_video.height],
        frame_rate: ffmpeg_video.frame_rate,
        duration: ffmpeg_video.duration,
        video_codec: ffmpeg_video.video_codec,
        video_bitrate: ffmpeg_video.video_bitrate,
        colorspace: ffmpeg_video.colorspace,
        audio_codec: ffmpeg_video.audio_codec,
        audio_bitrate: ffmpeg_video.audio_bitrate,
        audio_sample_rate: ffmpeg_video.audio_sample_rate
    }
  end

  def screengrab(output_file)
    #if transpose
    #ffmpeg_video.screenshot(output_file, custom: "-vf \"transpose=#{transpose}\"")
    #else
    #ffmpeg_video.screenshot(output_file)
    #end
    #
    ffmpeg_video.screenshot(output_file)

    image = ::MiniMagick::Image.new(output_file)
    image.resize "320x320^"
    image.gravity "center"
    image.crop "320x320+0+0"
    output_file
  end

  def gif(output_file)

    rate = 2.00 / @ffmpeg_video.duration

    #take the video and create the gif
    gif_command = "ffmpeg -i " << @path << " -filter:v " + '"setpts=' + rate.to_s + '*PTS" ' << "-pix_fmt rgb24 -r 1  #{output_file}"

    Movie.execute_process(gif_command) #create the temporary gif file

    output_file
  end

  def blurred_screengrab(output_file)
    #ffmpeg_video.screenshot(output_file, custom: "-vf \"transpose=1\"")
    ffmpeg_video.screenshot(output_file)
    image = ::MiniMagick::Image.new(output_file)
    #image.gaussian_blur "0x5"
    image.combine_options do |cmd|
      cmd.auto_gamma
      cmd.modulate '100,120'
    end
    output_file
  end

  private

  def ffmpeg_video
    @ffmpeg_video ||= ::FFMPEG::Movie.new(path)
  end
end
