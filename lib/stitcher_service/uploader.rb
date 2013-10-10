class Uploader
  attr_accessor :bucket

  def initialize(bucket)
    @bucket = bucket
  end

  def upload_to_s3(path, key)
    s3_obj = bucket.objects[key]
    retries = 3
    begin
      s3_obj.write(File.open(path, 'rb', :encoding => 'BINARY'))
    rescue => ex
      retries -= 1
      if retries > 0
        puts "ERROR during S3 upload: #{ex.inspect}. Retries: #{retries} left"
        retry
      else
        # oh well, we tried...
        raise
      end
    end
  end
end
