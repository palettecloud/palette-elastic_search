module Palette
  module ElasticSearch
    class Logger
      include Singleton

      def adapter
        if Configuration.instance.logging_adapter.to_sym == :new_relic
          NewRelicLoggingAdapter.instance
        else
          StdLoggingAdapter.instance
        end
      end

      def error(error)
        adapter.error error
      end
    end

  end
end