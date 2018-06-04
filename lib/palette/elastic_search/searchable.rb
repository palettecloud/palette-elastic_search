module Palette
  module ElasticSearch
    module Searchable
      module ClassMethods
        deprecated_analyzer = [:bigram].freeze

        def update_elasticsearch_index!(options={})
          if current_indices.present?
            reindex!(options)
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

        def get_old_index_name
          current_indices.first
        end

        def indexing(new_index_name, options={})
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
            self.__elasticsearch__.import(index: new_index_name, query: -> { where(updated_at: previous_start_at..Time.current) })
            process_end_at = Time.current
          end
        end

        def create_index!(options={})
          new_index_name = get_new_index_name
          indexing(new_index_name, options)
          self.__elasticsearch__.client.indices.update_aliases body: {
            actions: [
              { add: { index: new_index_name, alias: self.index_name } }
            ]
          }
        end

        def reindex!(options={})
          new_index_name = get_new_index_name
          old_index_name = get_old_index_name
          indexing(new_index_name, options)
          self.__elasticsearch__.client.indices.update_aliases body: {
            actions: [
              { remove: { index: old_index_name, alias: self.index_name } },
              { add: { index: new_index_name, alias: self.index_name } }
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

      extend ::ActiveSupport::Concern
      included do
        include ::Elasticsearch::Model
        include ::Elasticsearch::Model::Callbacks

        # @note for soft delete
        after_destroy :delete_document

        def delete_document
          self.__elasticsearch__.delete_document
        end

        index_name { "#{Rails.env.downcase.underscore}_#{self.connection.current_database}_#{self.table_name.underscore}" }
        document_type self.table_name.underscore.singularize

        settings index:
                   {
                     number_of_shards:   1,
                     number_of_replicas: 0,
                     analysis: {
                       tokenizer: {
                         kuromoji_search: {
                           type: 'kuromoji_tokenizer',
                           mode: 'search'
                         },
                         kuromoji_normal: {
                           type: 'kuromoji_tokenizer',
                           mode: 'normal'
                         },
                         kuromoji_extended: {
                           type: 'kuromoji_tokenizer',
                           mode: 'extended'
                         },
                         bi_gram: {
                           type: 'ngram',
                           min_gram: 2,
                           max_gram: 2,
                           token_chars: %W(letter digit)
                         },
                         n_gram: {
                           type: 'ngram',
                           min_gram: 1,
                           max_gram: 2,
                           token_chars: %W(letter digit)
                         }
                       },
                       analyzer: {
                         kuromoji_analyzer: {
                           type: 'custom',
                           tokenizer: 'kuromoji_tokenizer',
                           filter: %W(kuromoji_baseform),
                           char_filter: %W(my_icu_normalizer)
                         },
                         keyword_analyzer: {
                           type: 'custom',
                           tokenizer: 'whitespace',
                           char_filter: %W(my_icu_normalizer)
                         },
                         company_name_analyzer: {
                           type: 'custom',
                           tokenizer: 'keyword',
                           char_filter: %W(my_icu_normalizer company_name_trimmer)
                         },
                         bigram: {
                           tokenizer: 'bi_gram',
                           char_filter: %W(my_icu_normalizer)
                         },
                         ngram: {
                           tokenizer: 'n_gram',
                           char_filter: %W(my_icu_normalizer)
                         },
                         katakana: {
                           tokenizer: 'n_gram',
                           char_filter: %W(my_icu_normalizer)
                         },
                         postcode_analyzer: {
                           type: 'custom',
                           tokenizer: 'keyword',
                           char_filter: %W(my_icu_normalizer hyphen_normalizer postcode_normalizer)
                         },
                       },
                       filter: {
                         katakana_readingform: {
                           type: 'kuromoji_readingform',
                           use_romaji: false
                         },
                         custom_katakana_stemmer: {
                           type: 'kuromoji_stemmer',
                           minimum_length: 4
                         },
                         pos_filter: {
                           type:     'kuromoji_part_of_speech',
                           stoptags: %W(助詞-格助詞-一般　助詞-終助詞),
                         },
                         greek_lowercase_filter: {
                           type:     'lowercase',
                           language: 'greek',
                         }
                       },
                       char_filter: {
                         my_icu_normalizer: {
                           type: 'icu_normalizer',
                           name: 'nfkc_cf',
                           mode: 'compose'
                         },
                         company_name_trimmer: {
                           type: 'pattern_replace',
                           pattern: '[株式会社|会社]',
                           replacement: ''
                         },
                         postcode_normalizer: {
                           type: 'pattern_replace',
                           pattern: '(\d{3})(\d{4})',
                           replacement: '$1-$2'
                         },
                         hyphen_normalizer: {
                           type: 'pattern_replace',
                           pattern: '[\x{30FC}\x{2010}-\x{2015}\x{2212}\x{FF70}-]',
                           replacement: '-'
                         },
                       }
                     }
                   }
      end
    end
  end
end
