module Palette
  module ElasticSearch
    module Scrolling      
      def self.included(base)
        base.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def find_in_batches(batch_size: 1000)
            scroll = '1m'
            scroll_request = Class.new do
              attr_reader :klass, :options
      
              def initialize(klass, options={})
                @klass   = klass
                @options = options
      
                unless @options[:scroll_id].present?
                  raise ArgumentError, 'scroll_id is required.'
                end
              end
      
              def execute!
                klass.client.scroll(@options)
              end
            end

            self.search.definition.delete :scroll
            self.search.definition.update size: batch_size

            unless block_given?
              return to_enum(:find_in_batches, batch_size: batch_size) do
                batch_size > 0 ? (self.results.total - 1) / batch_size + 1 : 0
              end
            end

            self.search.definition.update scroll: scroll

            response = self
            pages_remain = batch_size > 0 ? (response.results.total - 1) / batch_size : 0
            loop do
              yield response
              break unless pages_remain > 0

              request = scroll_request.new(self.search.klass, scroll_id: response.response['_scroll_id'], scroll: scroll)
              response = self.class.new(self.search.klass, request)
              pages_remain -= 1
            end
          end
        RUBY
      end
    end
  end
end