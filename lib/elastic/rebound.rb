require 'rubberband'
require "elastic/rebound/version"
require "elastic/rebound/adaptor"
require "elastic/rebound/index_job"
require "elastic/rebound/result"
require "elastic/rebound/simple_strategy"
require "elastic/rebound/strategy"
require "elastic/rebound/active_callback"
require "resque"


module Elastic
  module Rebound

    @@index_client =  nil
    @@config = {}
    @@testing_mode = false

    def self.config=(data)
      @@config = data
    end

    def self.testing_mode(mode = true)
      @@testing_mode = mode
    end

    # Example Config
    # Elastic::Rebound.config = {
    #    :object_types => {
    #        Applet => {
    #            :active_record => true,
    #            :indexers => {
    #                SearchService::AppletIndexAdaptor => {}
    #            }
    #        },
    #        App => {
    #            :active_record => true,
    #            :indexers => {
    #                SearchService::AppIndexAdaptor => {}
    #            }
    #        }
    #    },
    #    :elastic_search_url => configatron.elasticsearch.url
    # }

    def self.config
      @@config
    end

    def self.client
      @@index_client =  @@index_client || ElasticSearch.new(Elastic::Rebound.config[:elastic_search_url])
    end

    def self.status
      index =   Elastic::Rebound.config[:object_types].try(:[],:indexers).try(:[],0)
      Elastic::Rebound.index_status(index) if index
    end

    def self.unindex(indexable)
      if Elastic::Rebound.config[:object_types][indexable.class]
        Elastic::Rebound.config[:object_types][indexable.class][:indexers].each_pair do |idxer,value|
          adapter = idxer.new
          if adapter.async? && !@@testing_mode
            Resque.enqueue(Elastic::Rebound::IndexJob, adapter.class.name, indexable.id, indexable.class.name,true)
          else
            adapter.unindex(indexable.id)
            adapter.refresh_index if @@testing_mode
          end
        end
      end
    end

  	def self.index(indexable)
      if Elastic::Rebound.config[:object_types][indexable.class]
        Elastic::Rebound.config[:object_types][indexable.class][:indexers].each_pair do |idxer,value|
          adapter = idxer.new
          if adapter.async? && !@@testing_mode
            Resque.enqueue(Elastic::Rebound::IndexJob, adapter.class.name, indexable.id, indexable.class.name,false)
          else
            data = adapter.index_data(indexable)
            adapter.index(data)
            adapter.refresh_index if @@testing_mode
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

    ESCAPE_LUCENE_REGEX = /
      ( [-+!\(\)\{\}\[\]^"~*?:\\] # A special character
        | &&                      # Boolean &&
        | \|\|                    # Boolean ||
      )/x.freeze

    # Escapes per https://lucene.apache.org/core/3_6_0/queryparsersyntax.html#Escaping
    def self.escape_query(query)
      query.gsub(ESCAPE_LUCENE_REGEX) { |m| "\\#{m}" }
    end

  end
end
