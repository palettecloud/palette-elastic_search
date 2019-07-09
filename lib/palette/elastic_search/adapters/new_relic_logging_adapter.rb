module Palette
  module ElasticSearch
    class NewRelicLoggingAdapter
      attr_accessor :logger

      def initialize
        @logger = ::NewRelic::Agent
      end

      def error(error)
        logger.notice_error error
      end

    end
  end
end