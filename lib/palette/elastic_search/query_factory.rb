module Palette
  module ElasticSearch
    module QueryFactory
      PARTIAL_MATCH_ANALYZERS = %w(kuromoji_analyzer ngram katakana).freeze

      module ModuleMethods
        # @param [Array<ActiveRecord::Base>] models 検索対象のモデルの配列
        # @param [Hash] attributes 検索条件
        def build(models, attributes)
          format_geo_point!(attributes)
          set_mappings_hashes(models)
          query_array = []
          geo_point_query = {}

          attributes.keys.each do |attr|
            field = field_for(attr)
            type = type_for(attr)

            query_partial = {}
            query_pattern = get_query_pattern(field.to_sym)

            case query_pattern[:pattern].to_sym
              when :partial_match
                # 部分一致
                query_partial = query_partial_for((attributes[attr]).to_s, [field], type)
              when :full_match_with_analyzer
                # 完全一致
                query_partial = full_match_for((attributes[attr]).to_s, field, query_pattern[:analyzer], type)
              when :geo_point
                # 位置情報フィルタ
                geo_point_query = geo_point_for(attributes)
              when :date
                # 日付検索
                query_partial = date_for(attributes, field)
            end

            query_array << query_partial if query_partial.present?
          end

          query = { query: { bool: { must: query_array, filter: geo_point_query } } }
          # @note debugしやすいようにログを出力しておく
          Rails.logger.debug query
          query
        end

        private

        # attr から field を取得する
        # ex. attr = building.name, field => name
        #
        # @param [Symbol] attr
        # @return [String] field
        def field_for(attr)
          if attr.to_s.include?('.')
            attr.to_s.split('.').second
          else
            attr.to_s
          end
        end

        # attr から type を取得する
        # ex. attr = building.name, type => building
        #
        # @param [Symbol] attr
        # @return [String] type
        def type_for(attr)
          attr.to_s.split('.').first if attr.to_s.include?('.')
        end

        # 部分一致のクエリを生成
        # @note query に空白が含まれる場合は、AND検索を行う
        #
        # @param [String] query
        # @param [String] fields
        # @param [String] type
        # @return [Hash]
        def query_partial_for(query, fields, type = nil)
          hash = if type.present?
                   # @note type がある場合は、typeを指定してクエリを生成する
                   { bool: { must: [{ type: { value: type } }] } }
                 else
                   { bool: { must: [] } }
                 end
          query.sub(/\A[[:space:]]+/, '').split(/[[:blank:]]+/).each do |q|
            hash[:bool][:must] << { simple_query_string: { query: q, fields: fields, analyzer: 'ngram' } }
          end
          hash
        end

        # 完全一致のクエリを生成
        #
        # @param [String] query
        # @param [String] field
        # @param [String] analyzer
        # @param [String] type
        # @return [Hash]
        # @note analyzerが"keyword_analyzer"の場合で、
        # queryに半角スペースが含まれる場合には半角区切文字列それぞれの完全一致のor検索となるようにしている。
        def full_match_for(query, field, analyzer, type = nil)
          hash = { bool: { must: [] } }
          hash[:bool][:must] << { match: { field => { query: query, analyzer: analyzer } } }
          return hash if type.blank?
          # @note type がある場合は、typeを指定してクエリを生成する
          hash[:bool][:must] << { match_phrase: { type: { value: type } } }
          hash
        end

        # ジオフィルタ
        #
        # @param [Hash] attributes
        # @return [Hash]
        def geo_point_for(attributes)
          { geo_distance: { distance: attributes[:geo_point][:distance], location: "#{attributes[:geo_point][:latitude]},#{attributes[:geo_point][:longitude]}" } }
        end

        # 日付検索クエリ
        #
        # @param [Hash] attributes
        # @return [Hash]
        def date_for(attributes, field)
          query = {}
          if attributes[field.to_sym].is_a?(Range)
            query = { range: { field => { gte: attributes[field.to_sym].first.beginning_of_day, lte: attributes[field.to_sym].last.end_of_day } } }
          elsif attributes[field.to_sym].is_a?(Date)
            query = { range: { field => { gte: attributes[field.to_sym].beginning_of_day, lte: attributes[field.to_sym].end_of_day } } }
          elsif attributes[field.to_sym].is_a?(ActiveSupport::TimeWithZone)
            query = { range: { field => { gte: Date.parse(attributes[field.to_sym].to_s) } } }
          end
          query
        end

        # 各モデルのマッピング情報を一つのhashにまとめる
        #
        # @param [Array<ActiveRecord::Base>] models
        # @return [void]
        def set_mappings_hashes(models)
          @mappings_hashes = {}
          models.each do |model|
            next if @mappings_hashes[model.document_type.to_sym].present?
            @mappings_hashes[model.document_type.to_sym] = model.mappings.to_hash[model.document_type.to_sym][:properties]
          end
          @mappings_hashes
        end

        # 要素名から適切なクエリのパターンを取得する
        #
        # @param [Symbol] field
        # @return [void]
        def get_query_pattern(field)
          return { pattern: 'geo_point' } if field.to_sym == :geo_point
          # 各モデルを走査する
          @mappings_hashes.keys.each do |index|
            if @mappings_hashes[index][field].present? && @mappings_hashes[index][field][:type].to_sym == :date
              return { pattern: 'date' }
            end

            next unless @mappings_hashes[index][field]&.has_key?(:analyzer)
            # analyzer が指定されていて、かつ PARTIAL_MATCH_ANALYZERSに含まれる場合は部分一致検索をする
            if PARTIAL_MATCH_ANALYZERS.include?(@mappings_hashes[index][field][:analyzer])
              return { pattern: 'partial_match' }
              # analyzer が指定されていて、かつ PARTIAL_MATCH_ANALYZERSに含まれない場合はanalyzerを指定した上で全体一致検索をする
            else
              return { pattern: 'full_match_with_analyzer', analyzer: @mappings_hashes[index][field][:analyzer] }
            end
          end
          # analyzerが指定されていない場合は(keyword, text以外の場合)部分一致検索をする。
          { pattern: 'partial_match' }
        end

        def format_geo_point!(attributes)
          # geo_pointに必要なkeyが一つもなければ何もしない
          return unless attributes.key?(:longitude) || attributes.key?(:latitude) || attributes.key?(:distance)
          # geo_pointに必要なkeyがすべて揃っていなければ存在するkeyを削除する
          unless attributes.key?(:longitude) && attributes.key?(:latitude) && attributes.key?(:distance)
            delete_geo_point_attributes!(attributes)
            return
          end
          # geo_pointに必要なkeyがすべて揃っていれば整形する
          attributes[:geo_point] = { latitude: attributes[:latitude], longitude: attributes[:longitude], distance: attributes[:distance] }
          delete_geo_point_attributes!(attributes)
          attributes
        end

        def delete_geo_point_attributes!(attributes)
          attributes.delete(:longitude)
          attributes.delete(:latitude)
          attributes.delete(:distance)
        end
      end
      extend ModuleMethods
    end
  end
end
