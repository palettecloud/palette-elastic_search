module Palette
  module ElasticSearch
    class Logger
      include Singleton
      attr_accessor :adapter

      def initialize
        @adapter = if Configuration.instance.logger_adapter == 'new_relic'
                     ::Palette::ElasticSearch::NewRelicLoggingAdapter.new
                   else
                     ::Palette::ElasticSearch::StdLoggingAdapter.new
                   end
      end

      def error(error)
        @adapter.error error
      end
    end

  end
end