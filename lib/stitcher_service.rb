$:.unshift File.dirname(__FILE__)

require 'syslog/logger'
require 'stitcher_service/movie'
require 'stitcher_service/cacher'
require 'stitcher_service/uploader'
require 'stitcher_service/worker'
require 'stitcher_service/worker_group'

class StitcherService
  def self.configure
    yield self
  end

  def self.logger
    @logger ||= self.create_logger
  end

  def self.start(*args)
    trap('SIGTERM') do
      puts "exiting"
      exit
    end
    WorkerGroup.pool(Worker, as: :workers, args: args, size: 10)
    WorkerGroup.run
  end

  private

  def self.create_logger
    logger = Syslog::Logger.new("stitcher")
    logger.level = Logger::INFO
    logger
  end
end
