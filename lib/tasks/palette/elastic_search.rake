namespace :palette do
  namespace :elastic_search do
    desc 'update elasticsearch index'
    task update_index!: :environment do
      begin

        if ENV['CLASS'].present? && (model = ENV['CLASS'].constantize).present?
          # update only specified model's index
          res = model.update_elasticsearch_index!
          Rails.logger.info res
        elsif ENV['CLASS'].present? && (model = ENV['CLASS'].constantize).blank?
          Rails.logger.error "ENV['CLASS'] is not found"
        else
          Rails.logger.info 'start updating all elasticsearch indices'

          Rails.application.eager_load!

          models = ObjectSpace.each_object(Class).select{ |s| s.ancestors.include?(ActiveRecord::Base) && s.respond_to?(:__elasticsearch__) }
          models.each do |model|
            Rails.logger.info "update index of #{model.name}"
            res = model.update_elasticsearch_index!
            Rails.logger.info res
          end

          Rails.logger.info 'finished updating all elasticsearch indices'

        end

      rescue => e
        Rails.logger.error e
      end
    end

    desc 'delete elasticsearch index'
    task delete_index!: :environment do
      begin

        if ENV['CLASS'].present? && (model = ENV['CLASS'].constantize).present?
          # delete only specified model's index
          res = model.delete_elasticsearch_index!
          Rails.logger.info res
        elsif ENV['CLASS'].present? && (model = ENV['CLASS'].constantize).blank?
          Rails.logger.error "ENV['CLASS'] is not found"
        else
          Rails.logger.info 'start deleting all elasticsearch indices'
          Elasticsearch::Model.client.perform_request 'DELETE', '*'
          Rails.logger.info 'finished deleting all elasticsearch indices'
        end

      rescue => e
        Rails.logger.error e
      end
    end
  end
end
