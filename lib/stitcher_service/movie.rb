class Movie
  include StitcherService::Util

  def self.stitch(files=[], output_file)
    raise "no files were included in the stitch request" if files.empty?

    tmpdir = File.dirname(output_file)
    inter_file = File.join(tmpdir, "inter.mpg")

    # check rotation
    movie = Movie.new(files.first)
    rotation = movie.rotation

    # transmux to mpg container format
    mpgs = files.map do |file|
      movie = Movie.new(file)

      if movie.valid?
        mpg_movie = movie.mpgify
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
    output = system(command)

    # create the final file
    command = "ffmpeg -i #{inter_file}"
    if rotation
      command << " -metadata:s:v:0 rotate=#{rotation}"
    end
    command << " -qscale:v 4 #{output_file}"
    output = system(command)
    logger.info output

    #interleave
    command = "MP4Box -inter 1000 #{output_file}"
    output = system(command)
    logger.info output

    self.new(output_file)
  end

  attr_accessor :path

  def initialize(filepath)
    @path = filepath
  end

  def mpgify
    new_filepath = "#{self.path}.mpg"
    mpg_command = "ffmpeg -i #{self.path} -y -qscale:v 1 "
    if transpose
      mpg_command << "-vf \"transpose=#{transpose}\" "
    end
    mpg_command << new_filepath
    p mpg_command

    output = system(mpg_command)
    Movie.new(new_filepath)
  end

  def valid?
    ffmpeg_video.valid? and ffmpeg_video.duration > 0.3
  end

  def duration
    ffmpeg_video.duration
  end

  def rotation
    command = "ffprobe -v quiet -print_format json -show_streams #{path}"
    Open3.popen3(command) do |stdin, stdout, stderr|
      data = JSON.parse(stdout.read)["streams"]
      if data
        data = data.map {|stream| stream["tags"]["rotate"] }.compact
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
    when "180"
      2
    when "270"
      3
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
