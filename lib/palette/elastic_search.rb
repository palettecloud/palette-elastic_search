require 'palette/elastic_search/version'
require 'active_support/concern'
require 'elasticsearch/rails'
require 'elasticsearch/model'

module Palette
  module ElasticSearch
    autoload :Searchable, 'palette/elastic_search/searchable'
    autoload :QueryFactory, 'palette/elastic_search/query_factory'
  end
end
