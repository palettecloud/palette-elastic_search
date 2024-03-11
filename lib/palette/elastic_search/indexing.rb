module Palette
  module ElasticSearch
    module Indexing

      module InstanceMethods
        extend ::ActiveSupport::Concern
        include ::Elasticsearch::Model

        def palette_index_document
          begin
            index_document
          rescue ::Elasticsearch::Transport::Transport::Errors::Conflict => e
            ::Palette::ElasticSearch::Logger.instance.error e
          end
        end

        def palette_update_document
          begin
            # call update_document_attributes directly so as not to call index_document automatically
            # @see https://github.com/elastic/elasticsearch-rails/blob/v5.1.0/elasticsearch-model/lib/elasticsearch/model/indexing.rb#L400
            update_document_attributes(self.as_indexed_json, {retry_on_conflict: 1})
          rescue ::Elasticsearch::Transport::Transport::Errors::NotFound
            # check whether record has already been destroyed
            unless self.class.exists?(id: self.id)
              palette_delete_document
              return
            end

            palette_index_document
          rescue ::Elasticsearch::Transport::Transport::Errors::Conflict => e
            ::Palette::ElasticSearch::Logger.instance.error e
          end
        end

        def palette_delete_document
          begin
            delete_document
          rescue ::Elasticsearch::Transport::Transport::Errors::NotFound => e
            ::Palette::ElasticSearch::Logger.instance.error e
          rescue ::Elasticsearch::Transport::Transport::Errors::Conflict => e
            ::Palette::ElasticSearch::Logger.instance.error e
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
          self.__elasticsearch__.client.indices.get_alias(name: self.index_name).keys
        end

        def get_new_index_name
          "#{self.index_name}_#{Time.current.strftime("%Y%m%d_%H%M%S")}"
        end

        def indexing(new_index_name, options = {})
          check_deprecated_analyzer
          self.__elasticsearch__.client.indices.create(
            {
              index: new_index_name,
              body: {
                settings: self.settings.to_hash,
                mappings: self.mappings.to_hash
              }
            }.merge(options)
          )
          self.__elasticsearch__.import(index: new_index_name, query: options[:query])
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

          process_start_at = Time.current
          indexing(new_index_name, options)
          process_end_at = Time.current

          self.__elasticsearch__.client.indices.update_aliases body: {
              actions: [
                  {remove: {index: old_index_name, alias: self.index_name}},
                  {add: {index: new_index_name, alias: self.index_name}}
              ]
          }

          self.where(updated_at: (process_start_at..process_end_at)).find_each do |record|
            record.__elasticsearch__.palette_update_document
          end

          self.__elasticsearch__.client.indices.delete index: old_index_name rescue nil
        end

        def check_deprecated_analyzer
          self.mappings.to_hash[:properties].keys.each do |key|
            case self.mappings.to_hash[:properties][key][:analyzer]
            when 'bigram'
              Rails.logger.warn 'bigram is deprecated. use ngram instead'
            end
          end
        end
      end
    end
  end
end
