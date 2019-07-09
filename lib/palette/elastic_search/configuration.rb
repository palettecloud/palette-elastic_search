module Palette
  module ElasticSearch
    class Configuration
      include Singleton
      attr_accessor :run_callbacks
      attr_accessor :logging_adapter

      def initialize
        @run_callbacks = true
        @logging_adapter = :rails
      end
    end
  end
end
