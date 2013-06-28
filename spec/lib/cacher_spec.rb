require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Cacher do
  before do
    @cacher = Cacher.new
  end

  it "grabs a single video from url" do
    url = "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
    Dir.mktmpdir do |dir|
      file = @cacher.get_file_from_url(url, "#{dir}/1.mp4")
      File.exist?(file.path).should be_true
    end
  end

  it "grabs a list of videos and stores it in the tmp dir" do
    urls = [
      "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
      "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
    ]

    @cacher.get(urls) do |files|
      files.should be_a_kind_of(Array)
      files.count.should == 2
    end
  end
end
