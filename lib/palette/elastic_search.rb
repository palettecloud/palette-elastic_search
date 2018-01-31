require 'palette/elastic_search/version'
require 'active_support/concern'
require 'elasticsearch/rails'
require 'elasticsearch/model'
require 'rails'

module Palette
  module ElasticSearch
    autoload :Searchable, 'palette/elastic_search/searchable'
    autoload :QueryFactory, 'palette/elastic_search/query_factory'

    class Railtie < ::Rails::Railtie
      rake_tasks do
        load 'tasks/palette/elastic_search.rake'
      end
    end
  end
end
