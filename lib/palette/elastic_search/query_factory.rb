module Palette
  module ElasticSearch
    module QueryFactory
      PARTIAL_MATCH_ANALYZERS = %w(kuromoji_analyzer bigram katakana).freeze

      module ModuleMethods
        # @param [Array<ActiveRecord::Base>] models
        # @param [Hash] attributes
        def build(models, attributes)
          format_geo_point!(attributes)
          set_mappings_hashes(models)
          query_array = []
          geo_point_query = {}

          attributes.keys.each do |attr|
            field = attr

            query_partial = {}
            query_pattern = get_query_pattern(field.to_sym)
            case query_pattern[:pattern].to_sym
              when :partial_match
                query_partial = query_partial_for((attributes[attr]).to_s, field, query_pattern[:analyzer].to_sym)
              when :full_match_with_analyzer
                query_partial = full_match_for((attributes[attr]).to_s, field, query_pattern[:analyzer].to_sym)
              when :integer
                query_partial = integer_for(attributes, field)
              when :prefix_match
                query_partial = prefix_match_for((attributes[attr]).to_s, field)
              when :geo_point
                geo_point_query = geo_point_for(attributes)
              when :date
                query_partial = date_for(attributes, field)
              when :nested
                query_partial = nested_for((attributes[attr]).to_s, field)
            end

            query_array << query_partial if query_partial.present?
          end

          if geo_point_query.present?
            { query: { bool: { must: query_array, filter: geo_point_query } } }
          else
            { query: { bool: { must: query_array} } }
          end
        end

        private

        # generate simple_query_string query
        #
        # @param [String] query
        # @param [String] field
        # @return [Hash]
        def query_partial_for(query, field, analyzer)
          hash = { bool: { must: [] } }
          query.sub(/\A[[:space:]]+/, '').split(/[[:blank:]]+/).each do |q|
            hash[:bool][:must] << { simple_query_string: { query: q, fields: [field], analyzer: analyzer } }
          end
          hash
        end

        # generate match query
        #
        # @param [String] query
        # @param [String] field
        # @param [String] analyzer
        # @return [Hash]
        def full_match_for(query, field, analyzer)
          { bool: { must: [{ match: { field => { query: query, analyzer: analyzer } } }] } }
        end

        # 前方一致のクエリを生成
        #
        # @param [String] query
        # @param [String] field
        # @return [Hash]
        def prefix_match_for(query, field)
          { bool: { must: [{ match: { field => { query: query, analyzer: 'whitespace' }}}]} }
        end

        # for geo_point query
        #
        # @param [Hash] attributes
        # @return [Hash]
        def geo_point_for(attributes)
          { geo_distance: { distance: attributes[:geo_point][:distance], location: "#{attributes[:geo_point][:latitude]},#{attributes[:geo_point][:longitude]}" } }
        end

        # for date query
        #
        # @param [Object] attributes
        # @param [Symbol] field
        # @return [Hash]
        def date_for(attributes, field)
          attributes = attributes.symbolize_keys
          field = field.to_sym
          case attributes[field]
            when Hash
              attributes[field] = attributes[field].symbolize_keys
              query = { range: { field => {} } }
              if attributes[field].symbolize_keys.keys.include?(:gte) && attributes[field].symbolize_keys[:gte].present?
                query[:range][field][:gte] = attributes[field][:gte]
              end
              if attributes[field.to_sym].symbolize_keys.keys.include?(:lte) && attributes[field].symbolize_keys[:lte].present?
                query[:range][field.to_sym][:lte] = attributes[field][:lte]
              end
              if query[:range][field].nil?
                return {}
              else
                query
              end
            when Range
              return { range: { field => { gte: attributes[field].first.beginning_of_day, lte: attributes[field].last.end_of_day } } }
            when Date
              return { range: { field => { gte: attributes[field].beginning_of_day, lte: attributes[field].end_of_day } } }
            when ActiveSupport::TimeWithZone
              return { range: { field => { gte: Date.parse(attributes[field].to_s) } } }
            else
              return {}
          end
        end
        

        # for integer query
        #
        # @params [Object] attributes
        # @params [Symbol] field
        # @return [Hash]
        def integer_for(attributes, field)
          attributes = attributes.symbolize_keys
          field = field.to_sym
          return { term: { field => attributes[field] } }
        end

        # for nested query
        #
        # @param [String] query
        # @param [String] field
        # @return [Hash]
        def nested_for(query, field)
          path = field.to_s.split('.').first
          query_pattern = get_query_pattern(field.to_sym, true)
          case query_pattern[:pattern].to_sym
            when :partial_match
              return { nested: { path: path, query: query_partial_for(query, field) } }
            when :full_match_with_analyzer
              return { nested: { path: path, query: full_match_for(query, field, query_pattern[:analyzer]) } }
            else
              return nil
          end
        end

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

        # get analyzer pattern by the definitions of model's mappings
        #
        # @param [Symbol] field
        # @return [void]
        def get_query_pattern(field, should_nested = false)
          return { pattern: 'geo_point' } if field.to_sym == :geo_point
          @mappings_hashes.keys.each do |index|
            if type_by(index, field, should_nested).present? && type_by(index, field, should_nested) == :date
              return { pattern: 'date' }
            end
            if type_by(index, field, should_nested).present? && type_by(index, field, should_nested) == :integer
              return { pattern: 'integer'}
            end
            if type_by(index, field, should_nested).present? && type_by(index, field, should_nested) == :nested
              return { pattern: 'nested' }
            end

            case analyzer_by(index, field, should_nested).to_s
            when *PARTIAL_MATCH_ANALYZERS
              return { pattern: 'partial_match', analyzer: analyzer_by(index, field, should_nested) }
            when 'autocomplete_analyzer'
              return { pattern: 'prefix_match' }
            else
              return { pattern: 'full_match_with_analyzer', analyzer: analyzer_by(index, field, should_nested) }
            end
          end

          { pattern: 'partial_match' }
        end

        def type_by(index, field, should_nested = false)
          mapping = @mappings_hashes[index]
          if should_nested
            mapping = mapping[field.to_s.split('.').first.to_sym][:properties][field.to_s.split('.').last.to_sym]
          else
            mapping = mapping[field.to_s.split('.').first.to_sym]
          end
          mapping[:type]&.to_sym
        end

        def analyzer_by(index, field, should_nested = false)
          mapping = @mappings_hashes[index]
          if should_nested
            mapping = mapping[field.to_s.split('.').first.to_sym][:properties][field.to_s.split('.').last.to_sym]
          else
            mapping = mapping[field.to_s.split('.').first.to_sym]
          end
          mapping[:analyzer]&.to_sym
        end

        def format_geo_point!(attributes)
          return unless attributes.key?(:longitude) || attributes.key?(:latitude) || attributes.key?(:distance)

          unless attributes.key?(:longitude) && attributes.key?(:latitude) && attributes.key?(:distance)
            delete_geo_point_attributes!(attributes)
            return
          end

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
