class Uploader
  def self.upload_to_s3(path, s3_obj)
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
