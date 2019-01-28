module Palette
  module ElasticSearch
    class Configuration
      include Singleton
      attr_accessor :run_callbacks

      def initialize
        @run_callbacks = true
      end
    end
  end
end
