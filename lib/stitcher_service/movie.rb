class Movie
  def self.stitch(files=[], output_file)
    raise "there must be some files" if files.empty?

    command = "MP4Box -force-cat "
    files.each do |file|
      command << " -cat #{file}"
    end
    command << " -tmp #{File.dirname(output_file)}"
    command << " #{output_file}"

    p command
    system(command)

    self.new(output_file)
  end

  def initialize(file)
    @file = file
  end

  def screengrab(output_file)
    ffmpeg_video.screenshot(output_file)
    image = ::MiniMagick::Image.new(output_file)
    image.resize "90x90"
    output_file
  end

  private

  def ffmpeg_video
    @ffmpeg_video ||= ::FFMPEG::Movie.new(@file)
  end
end
