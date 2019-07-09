module Palette
  module ElasticSearch
    class Configuration
      include Singleton
      attr_accessor :run_callbacks
      attr_accessor :logger_adapter

      def initialize
        @run_callbacks = true
        @logger_adapter = 'rails'
      end
    end
  end
end
