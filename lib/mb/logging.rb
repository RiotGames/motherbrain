require 'logger'

module MotherBrain
  # @author Jamie Winsor <jamie@vialstudios.com>
  module Logging
    autoload :BasicFormat, 'mb/logging/basic_format'

    class << self
      # @return [Logger]
      def logger
        @logger ||= begin
          log = Logger.new(STDOUT)
          log.level = Logger::WARN
          log.formatter = BasicFormat.new
          log
        end
      end

      # @param [Logger, nil] obj
      #
      # @return [Logger]
      def set_logger(obj)
        @logger = (obj.nil? ? Logger.new('/dev/null') : obj)
      end
    end

    # @return [Logger]
    def logger
      MB::Logging.logger
    end
    alias_method :log, :logger
  end
end
