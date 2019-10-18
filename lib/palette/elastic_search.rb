require 'palette/elastic_search/version'
require 'active_support/concern'
require 'elasticsearch/rails'
require 'elasticsearch/model'
require 'newrelic_rpm'
require 'rails'

module Palette
  module ElasticSearch
    autoload :Searchable, 'palette/elastic_search/searchable'
    autoload :QueryFactory, 'palette/elastic_search/query_factory'
    autoload :Configuration, 'palette/elastic_search/configuration'
    autoload :Indexing, 'palette/elastic_search/indexing'
    autoload :Scrolling, 'palette/elastic_search/scrolling'
    autoload :Logger, 'palette/elastic_search/logger'
    autoload :NewRelicLoggingAdapter, 'palette/elastic_search/adapters/new_relic_logging_adapter'
    autoload :StdLoggingAdapter, 'palette/elastic_search/adapters/std_logging_adapter'

    def self.configuration
      Configuration.instance
    end

    def self.configure
      yield configuration
    end

    class Railtie < ::Rails::Railtie
      rake_tasks do
        load 'tasks/palette/elastic_search.rake'
      end
    end
  end
end
