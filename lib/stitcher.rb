class Stitcher
  def self.stitch(files=[], output)
    raise if files.empty?

    command = "mp4box -force-cat -hint"

    files.each do |file|
      command << " -cat #{file}"
    end

    command << " #{output}"

    p command
    system command

    output
  end
end
