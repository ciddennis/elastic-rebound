require 'rubberband'
require "elastic/rebound/version"
require "elastic/rebound/adaptor"
require "elastic/rebound/index_job"
require "elastic/rebound/result"
require "elastic/rebound/simple_strategy"
require "elastic/rebound/strategy"
require "elastic/rebound/active_callback"


module Elastic
  module Rebound

    @@index_client =  nil
    @@config = {}

    def self.config
      @@config = {
        :object_types => {
          Applet => {
            :active_record => true,
            :indexers => {
              AppletIndexAdaptor => {

              }
            }
          },
          App => {
            :active_record => true,
            :indexers => {
              AppIndexAdaptor => {

              }
            }
          },
          Caplet => {
            :active_record => true,
            :indexers => {
              CapletIndexAdaptor => {

              }
            }
          }
        },
        :elastic_search_url => configatron.elasticsearch.url
      }

      @@config
    end

    def self.client
      @@index_client =  @@index_client || ElasticSearch.new(Elastic::Rebound.config[:elastic_search_url])
    end

    def self.simple_test

      strategy = SearchService::AppletIndexAdaptor::AppletSearchStrategy.new
      strategy.full_text = "title"
      strategy.must_match = [strategy.simple_field(:title,"test"),strategy.simple_field(:description ,"test")]
      strategy.must_not_match = [strategy.simple_field(:title,"your"),strategy.simple_field(:description ,"character")]
      strategy.per_page = 50
      strategy.page = 1
      strategy.sort = "title.sortable"
      result = strategy.search

      ids = result.results.map(&:id)
      ids2 = result.results(true).map(&:id)

      pp ids
      pp ids2

    end
    def self.test_reindex
      Elastic::Rebound.reindex_all(Applet)
    end



    def self.unindex(indexable)
      if Elastic::Rebound.config[:object_types][indexable.class]
        Elastic::Rebound.config[:object_types][indexable.class][:indexers].each_pair do |idxer,value|
          adapter = idxer.new
          if adapter.async?
            Resque.enqueue(Elastic::Rebound::IndexJob, adapter.class.name, indexable.id, indexable.class.name,true)
          else
            adapter.unindex(indexable.id)
          end
        end
      end
    end

  	def self.index(indexable)
      if Elastic::Rebound.config[:object_types][indexable.class]
        Elastic::Rebound.config[:object_types][indexable.class][:indexers].each_pair do |idxer,value|
          adapter = idxer.new
          if adapter.async?
            Resque.enqueue(Elastic::Rebound::IndexJob, adapter.class.name, indexable.id, indexable.class.name,false)
          else
            data = adapter.index_data(indexable)
            adapter.index(data)
          end
        end
      end
    end

    #require "search_service/search_service";SearchService.reindex_all(Applet)
    def self.reindex_all(kind_to_index)
      adaptors = []

      Elastic::Rebound.config[:object_types][kind_to_index][:indexers].each_pair do |idxer,value|
        adaptors << idxer.new
      end
      adaptors.each do |a|
        a.create_index
      end

      kind_to_index.find_in_batches do  |group|
        index_data = []

        group.each do |o|
          adaptors.each do |a|
            a.index([a.index_data(o)])
          end
        end
      end
    end
  end
end
