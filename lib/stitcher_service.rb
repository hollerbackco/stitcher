$:.unshift File.dirname(__FILE__)

require 'syslog/logger'

module StitcherService
  class Pretty < Logger::Formatter
    def call(severity, time, program_name, message)
      "#{time.utc.iso8601} stitcher-#{ENV['SERVICE_ENV']} #{severity}: #{message}\n"
    end
  end

  def self.configure
    yield self
  end

  def self.error_sns=(sns)
    @error_sns ||= sns
  end

  def self.error_sns
    @error_sns
  end

  def self.logger
    @logger ||= self.create_logger
  end

  def self.start(*args)
    trap('SIGTERM') do
      puts "exiting"
      exit
    end
    WorkerGroup.pool(Worker, as: :workers, args: args, size: ENV['THREADS'])
    WorkerGroup.run
  end

  def self.notify_error(message)
    error_sns.publish(message)
  end

  private

  def self.create_logger
    #logger = Syslog::Logger.new("stitcher")
    logger = Logger.new(ENV['LOG_FILE'], 'daily')
    logger.level = Logger::INFO
    logger.formatter = ::StitcherService::Pretty.new
    FFMPEG.logger = logger
    logger
  end
end

require 'stitcher_service/util'
require 'stitcher_service/movie'
require 'stitcher_service/cacher'
require 'stitcher_service/uploader'
require 'stitcher_service/worker'
require 'stitcher_service/worker_group'
