class Stitcher
  def self.stitch(files=[], output)
    raise if files.empty?

    command = "MP4Box -force-cat "

    files.each do |file|
      command << " -cat #{file}"
    end

    command << " #{output}"

    p command
    system command

    output
  end
end
