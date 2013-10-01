class Movie
  include StitcherService::Util

  def self.stitch(files=[], output_file)
    raise "no files were included in the stitch request" if files.empty?

    command = "MP4Box -force-cat "
    files.each do |file|
      movie = Movie.new(file)
      if movie.valid?
        command << " -cat #{file}"
      else
        notify_error "[ERROR] invalid video part number: #{files.index(file)} - #{file}"
        logger.error "[ERROR] invalid video part number: #{files.index(file)} - #{file}"
      end
    end
    command << " -tmp #{File.dirname(output_file)}"
    command << " #{output_file}"

    logger.info "run mp4box with: #{command}"
    output = system(command)
    logger.info output

    self.new(output_file)
  end

  attr_accessor :file

  def initialize(file)
    @file = file
  end

  def valid?
    ffmpeg_video.valid?
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
    @ffmpeg_video ||= ::FFMPEG::Movie.new(@file)
  end
end
