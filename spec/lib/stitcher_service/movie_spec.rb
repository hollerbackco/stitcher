require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Movie do
  it "should stitch a file" do
    files = []
    Dir.glob(File.dirname(__FILE__) + '/../../fixtures/chunks/*.mp4') do |item|
      files << item
    end

    output = nil
    Dir.mktmpdir do |dir|
      output = "#{dir}/final.mp4"
      Movie.stitch(files, output)
      File.exist?(output).should be_true
    end

    File.exist?(output).should be_false
  end

  it "should take a screengrab" do
    file = Dir.glob(File.dirname(__FILE__) + '/../../fixtures/chunks/*.mp4').first
    Dir.mktmpdir do |dir|
      movie = Movie.new(file)
      thumb = movie.screengrab("#{dir}/test.png")
      File.exist?(thumb).should be_true
    end
  end

  it "should take a blurred screengrab" do
    file = Dir.glob(File.dirname(__FILE__) + '/../../fixtures/chunks/*.mp4').first
    Dir.mktmpdir do |dir|
      movie = Movie.new(file)
      thumb = movie.blurred_screengrab("#{dir}/test.png")
      File.exist?(thumb).should be_true
    end
  end

  it "should print info" do
    file = Dir.glob(File.dirname(__FILE__) + '/../../fixtures/chunks/*.mp4').first
    Dir.mktmpdir do |dir|
      movie = Movie.new(file)
      p movie.info
      movie.info.should_not be_nil
    end
  end

  it "should grab rotation" do
    movie = Movie.new(File.dirname(__FILE__) + '/../../fixtures/chunks/1.mp4')
    movie.rotation.should be_nil
  end
end
