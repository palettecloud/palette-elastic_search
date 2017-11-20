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
                query_partial = query_partial_for((attributes[attr]).to_s, field)
              when :full_match_with_analyzer
                query_partial = full_match_for((attributes[attr]).to_s, field, query_pattern[:analyzer])
              when :geo_point
                geo_point_query = geo_point_for(attributes)
              when :date
                query_partial = date_for(attributes, field)
            end

            query_array << query_partial if query_partial.present?
          end

          { query: { bool: { must: query_array, filter: geo_point_query } } }
        end

        private

        # generate simple_query_string query
        #
        # @param [String] query
        # @param [String] field
        # @return [Hash]
        def query_partial_for(query, field)
          hash = { bool: { must: [] } }
          query.sub(/\A[[:space:]]+/, '').split(/[[:blank:]]+/).each do |q|
            hash[:bool][:must] << { simple_query_string: { query: q, fields: [field], analyzer: 'bigram' } }
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

        # for geo_point
        #
        # @param [Hash] attributes
        # @return [Hash]
        def geo_point_for(attributes)
          { geo_distance: { distance: attributes[:geo_point][:distance], location: "#{attributes[:geo_point][:latitude]},#{attributes[:geo_point][:longitude]}" } }
        end

        # for date
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
        def get_query_pattern(field)
          return { pattern: 'geo_point' } if field.to_sym == :geo_point
          @mappings_hashes.keys.each do |index|
            if @mappings_hashes[index][field].present? && @mappings_hashes[index][field][:type].to_sym == :date
              return { pattern: 'date' }
            end

            next unless @mappings_hashes[index][field]&.has_key?(:analyzer)

            if PARTIAL_MATCH_ANALYZERS.include?(@mappings_hashes[index][field][:analyzer])
              return { pattern: 'partial_match' }
            else
              return { pattern: 'full_match_with_analyzer', analyzer: @mappings_hashes[index][field][:analyzer] }
            end
          end

          { pattern: 'partial_match' }
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
