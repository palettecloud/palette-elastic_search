module Palette
  module ElasticSearch
    module Searchable
      module ClassMethods
        def update_elasticsearch_index!
          if current_indices.present?
            # @note 既にindexが存在する場合はreindexを行う
            reindex!
          else
            # @note indexが存在しない場合は、indexを作成してデータのimportを行う
            create_index!
          end
        end

        def delete_elasticsearch_index!
          current_indices.each do |index|
            self.__elasticsearch__.client.indices.delete index: index rescue nil
          end
        end

        private

        # 先頭一致でindex_nameを含むindex一覧を取得する
        def current_indices
          self.__elasticsearch__.client.indices.get_aliases.keys.grep(/^#{self.index_name}/)
        end

        # 新規のindexの名前を設定する
        def get_new_index_name
          "#{self.index_name}_#{Time.now.strftime("%Y%m%d_%H%M%S")}"
        end

        # 稼働中のindexの名前を取得する
        def get_old_index_name
          current_indices.first
        end

        # index作成からデータの同期までの一連の処理を実行
        #
        # 1. indexを作成
        # 2. データをimport
        # 3. aliasを設定する
        def create_index!
          new_index_name = get_new_index_name
          # indexを作成する
          self.__elasticsearch__.client.indices.create index: new_index_name,
                                                       body: {
                                                         settings: self.settings.to_hash,
                                                         mappings: self.mappings.to_hash
                                                       }
          # データをimport
          self.__elasticsearch__.import(index: new_index_name)
          # aliasを設定する
          self.__elasticsearch__.client.indices.update_aliases body: {
            actions: [
              { add: { index: new_index_name, alias: self.index_name } }
            ]
          }
        end

        # mappingの切り替えの際の一連の処理を実行
        #
        # 1. 新たにindexを作成
        # 2. 新たなindexにデータをimport
        # 3. aliasの切り替え
        # 4. 古いindexを削除
        def reindex!
          new_index_name = get_new_index_name
          old_index_name = get_old_index_name
          # indexを作成
          self.__elasticsearch__.client.indices.create index: new_index_name,
                                                       body: {
                                                         settings: self.settings.to_hash,
                                                         mappings: self.mappings.to_hash
                                                       }
          # データをimport
          self.__elasticsearch__.import(index: new_index_name)
          # aliasの切り替え
          self.__elasticsearch__.client.indices.update_aliases body: {
            actions: [
              { remove: { index: old_index_name, alias: self.index_name } },
              { add: { index: new_index_name, alias: self.index_name } }
            ]
          }
          # 古いindexを削除する
          self.__elasticsearch__.client.indices.delete index: old_index_name rescue nil
        end

      end

      extend ::ActiveSupport::Concern
      included do
        include ::Elasticsearch::Model
        include ::Elasticsearch::Model::Callbacks

        # index_name self.table_name.underscore
        index_name "#{Rails.env.downcase.underscore}_#{self.connection.current_database}_#{self.table_name.underscore}"
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
                         }
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
                         }
                       }
                     }
                   }
      end
    end
  end
end
