module Palette
  module ElasticSearch
    module Indexing
      module InstanceMethods
        def es_index_document
          begin
            __elasticsearch__.index_document
          rescue ::Elasticsearch::Transport::Transport::Errors::Conflict => e
            ::Palette::ElasticSearch::Logger.instance.error e.message
          end
        end

        def es_update_document
          begin
            self.__elasticsearch__.update_document
          rescue ::Elasticsearch::Transport::Transport::Errors::NotFound
            es_index_document
          rescue ::Elasticsearch::Transport::Transport::Errors::Conflict => e
            ::Palette::ElasticSearch::Logger.instance.error e.message
          end
        end

        def es_delete_document
          begin
            __elasticsearch__.delete_document
          rescue ::Elasticsearch::Transport::Transport::Errors::Conflict => e
            ::Palette::ElasticSearch::Logger.instance.error e.message
          end
        end
      end

      module ClassMethods
        def update_elasticsearch_index!(options = {})
          if current_indices.present?
            if current_indices.include?(self.index_name)
              # @note when default index exists, delete default index and create new index with timestamp-suffix
              self.__elasticsearch__.client.indices.delete index: self.index_name rescue nil
              create_index!(options)
            else
              reindex!(options)
            end
          else
            create_index!(options)
          end
        end

        def delete_elasticsearch_index!
          current_indices.each do |index|
            self.__elasticsearch__.client.indices.delete index: index rescue nil
          end
        end

        private

        def current_indices
          self.__elasticsearch__.client.indices.get_aliases.keys.grep(/^#{self.index_name}/)
        end

        def get_new_index_name
          "#{self.index_name}_#{Time.now.strftime("%Y%m%d_%H%M%S")}"
        end

        def indexing(new_index_name, options = {})
          check_deprecated_analyzer
          self.__elasticsearch__.client.indices.create index: new_index_name,
                                                       body: {
                                                           settings: self.settings.to_hash,
                                                           mappings: self.mappings.to_hash
                                                       }
          process_start_at = Time.current
          self.__elasticsearch__.import(index: new_index_name, query: options[:query])
          process_end_at = Time.current

          # @note for new records generated while indexing
          loop do
            break if self.where(updated_at: process_start_at..process_end_at).empty?
            previous_start_at = process_start_at
            process_start_at = Time.current
            # @see https://github.com/elastic/elasticsearch-rails/blob/master/elasticsearch-model/lib/elasticsearch/model/importing.rb
            self.__elasticsearch__.import(index: new_index_name, query: -> {where(updated_at: previous_start_at..Time.current)})
            process_end_at = Time.current
          end
        end

        def create_index!(options = {})
          new_index_name = get_new_index_name
          indexing(new_index_name, options)
          self.__elasticsearch__.client.indices.update_aliases body: {
              actions: [
                  {add: {index: new_index_name, alias: self.index_name}}
              ]
          }
        end

        def reindex!(options = {})
          new_index_name = get_new_index_name
          old_index_name = current_indices.sort.last
          indexing(new_index_name, options)
          self.__elasticsearch__.client.indices.update_aliases body: {
              actions: [
                  {remove: {index: old_index_name, alias: self.index_name}},
                  {add: {index: new_index_name, alias: self.index_name}}
              ]
          }
          self.__elasticsearch__.client.indices.delete index: old_index_name rescue nil
        end

        def check_deprecated_analyzer
          self.mappings.to_hash[self.model_name.param_key.to_sym][:properties].keys.each do |key|
            case self.mappings.to_hash[self.model_name.param_key.to_sym][:properties][key][:analyzer]
            when 'bigram'
              Rails.logger.warn 'bigram is deprecated. use ngram instead'
            end
          end
        end
      end
    end
  end
end