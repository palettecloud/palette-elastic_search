module Palette
  module ElasticSearch
    module Searchable
      extend ::ActiveSupport::Concern

      # @see https://github.com/elastic/elasticsearch-rails/blob/5.x/elasticsearch-model/lib/elasticsearch/model.rb#L101
      ::Elasticsearch::Model::Proxy::InstanceMethodsProxy.class_eval do
        include ::Palette::ElasticSearch::Indexing::InstanceMethods
      end

      class_methods do
        include ::Palette::ElasticSearch::Indexing::ClassMethods

        # Set preference to _primary_first as default
        # To ensure results consistency over pages.
        # @see https://www.elastic.co/guide/en/elasticsearch/reference/5.0/search-request-preference.html#search-request-preference
        def search(query_or_payload, options={})
          __elasticsearch__.search query_or_payload, options.reverse_merge(preference: '_primary_first')
        end
      end

      included do
        include ::Elasticsearch::Model

        index_name { "#{Rails.env.downcase.underscore}_#{self.connection.current_database}_#{self.table_name.underscore}" }
        document_type self.table_name.underscore.singularize

        settings index:
                   {
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
                           max_gram: 20,
                           token_chars: %W(letter digit punctuation)
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
                           char_filter: %W(my_icu_normalizer space_trimmer)
                         },
                         ngram: {
                           tokenizer: 'n_gram',
                           char_filter: %W(my_icu_normalizer space_trimmer)
                         },
                         katakana: {
                           tokenizer: 'whitespace',
                           filter: %W(katakana_translator custom_katakana_stemmer ngram_filter),
                           char_filter: %W(my_icu_normalizer)
                         },
                         katakana_whitespace: {
                           tokenizer: 'whitespace',
                           filter: %W(katakana_translator custom_katakana_stemmer),
                           char_filter: %W(my_icu_normalizer)
                         },
                         number_code_analyzer: {
                           type: 'custom',
                           tokenizer: 'keyword',
                           char_filter: %W(my_icu_normalizer hyphen_trimmer)
                         },
                         autocomplete_analyzer: {
                           type: 'custom',
                           tokenizer: 'whitespace',
                           filter: %W(lowercase autocomplete_filter)
                         },
                         autocomplete_whitespace: {
                           type: 'custom',
                           tokenizer: 'whitespace',
                           filter: %W(lowercase)
                         }
                       },
                       filter: {
                         katakana_translator: {
                           type: 'icu_transform',
                           id: 'Hiragana-Katakana'
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
                         },
                         ngram_filter: {
                           type: 'ngram',
                           min_gram: 1,
                           max_gram: 100,
                         },
                         autocomplete_filter: {
                           type: 'edge_ngram',
                           min_gram: 1,
                           max_gram: 100,
                         },
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
                         hyphen_trimmer: {
                           type: 'pattern_replace',
                           pattern: '[\x{30FC}\x{2010}-\x{2015}\x{2212}\x{FF70}-]',
                           replacement: ''
                         },
                         space_trimmer: {
                          type: 'pattern_replace',
                          pattern: '[\s]',
                          replacement: ''
                        }
                       }
                     }
                   }
      end
    end
  end
end
