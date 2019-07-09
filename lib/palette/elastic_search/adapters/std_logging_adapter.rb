module Palette
  module ElasticSearch
    class StdLoggingAdapter
      include Singleton
      attr_accessor :logger

      def initialize
        @logger = ::Logger.new(STDOUT)
      end

      def error(error)
        logger.error error
      end

    end
  end
end