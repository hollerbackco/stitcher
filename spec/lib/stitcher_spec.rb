require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Stitcher do

  it "should stitch a file" do
    files = []
    Dir.glob(File.dirname(__FILE__) + '/../fixtures/chunks/*.mp4') do |item|
      files << item
    end

    output = nil
    Dir.mktmpdir do |dir|
      output = "#{dir}/1.mp4"
      Stitcher.stitch(files, output)
      File.exist?(output).should be_true
    end

    File.exist?(output).should be_false
  end
end
