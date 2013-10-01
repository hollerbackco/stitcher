module StitcherService
  module Util
    def logger
      defined?(@logger) ? @logger : self.class.logger
    end

    def notify_error(msg)
      self.class.notify_error(msg)
    end

    module ClassMethods
      def logger
        @logger ||= StitcherService.logger
      end

      def notify_error(msg)
        StitcherService.notify_error(msg)
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
