class Cacher
  def get(urls=[])
    Dir.mktmpdir do |dir|
     files = urls.map do |url|
        filename = generate_random_filename(dir, url)
        get_file_from_url url, filename
      end

      yield files, dir
    end
  end

  def get_file_from_url(url_string, filename)
    file = nil
    url = URI.parse(url_string)

    Net::HTTP.start(url.host) do |http|
      begin
        file = open(filename, 'wb')
        http.request_get(url.request_uri) do |response|
          response.read_body do |segment|
            file.write(segment)
          end
        end
      ensure
        file.close
      end
    end

    file
  end

  private

  def generate_random_filename(dir, url)
    ext = File.extname(url)
    File.join(dir, "#{SecureRandom.hex}.#{ext}")
  end
end
