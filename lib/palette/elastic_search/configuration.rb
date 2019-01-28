module Palette
  module ElasticSearch
    class Configuration
      include Singleton
      attr_accessor :run_callbacks
      attr_accessor :number_of_shards
      attr_accessor :number_of_replicas

      def initialize
        @run_callbacks = true
        @number_of_shards = 1
        @number_of_replicas = 0
      end
    end
  end
end
