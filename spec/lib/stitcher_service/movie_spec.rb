require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Movie do

  it "should stitch a file" do
    files = []
    Dir.glob(File.dirname(__FILE__) + '/../../fixtures/chunks/*.mp4') do |item|
      files << item
    end

    output = nil
    Dir.mktmpdir do |dir|
      output = "#{dir}/1.mp4"
      Movie.stitch(files, output)
      File.exist?(output).should be_true
    end

    File.exist?(output).should be_false
  end

  it "should take a screengrab" do
    file = Dir.glob(File.dirname(__FILE__) + '/../../fixtures/chunks/*.mp4').first
    Dir.mktmpdir do |dir|
      movie = Movie.new(file)
      thumb = movie.screengrab("#{tmp}/test.png")
      File.exist?(thumb).should be_true
    end
  end
end
