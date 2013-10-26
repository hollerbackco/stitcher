class Movie
  include StitcherService::Util

  def self.stitch(files=[], output_file)
    raise "no files were included in the stitch request" if files.empty?

    command = "MP4Box -force-cat "
    file = files.shift
    movie = Movie.new(file)
    command << " -add #{movie.path}"

    files.each do |file|
      movie = Movie.new(file)
      if movie.valid?
        command << " -cat #{movie.path}"
      else
        notify_error "[ERROR] invalid video part number: #{files.index(file)} - #{movie.path}"
        logger.error "[ERROR] invalid video part number: #{files.index(file)} - #{movie.path}"
      end
    end
    command << " -tmp #{File.dirname(output_file)}"
    command << " #{output_file}"

    logger.info "run mp4box with: #{command}"
    output = system(command)
    logger.info output

    self.new(output_file)
  end

  attr_accessor :path

  def initialize(filepath)
    @path = filepath
  end

  def valid?
    ffmpeg_video.valid?
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
    #ffmpeg_video.screenshot(output_file, custom: "-vf \"transpose=1\"")
    ffmpeg_video.screenshot(output_file)
    image = ::MiniMagick::Image.new(output_file)
    image.resize "320x320^"
    image.gravity "center"
    image.crop "320x320+0+0"
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
