require 'rubberband'
require "elastic/rebound/version"
require "elastic/rebound/adaptor"
require "elastic/rebound/index_job"
require "elastic/rebound/index_async_job"
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

    def self.client(options = {})
      ElasticSearch.new(Elastic::Rebound.config[:elastic_search_url], options.merge({:auto_discovery => false}))
    end

    def self.status
      index =   Elastic::Rebound.config[:object_types].try(:[],:indexers).try(:[],0)
      Elastic::Rebound.index_status(index) if index
    end

    # Given a object to index it will find that object type in the configration and
    # remove it from the index.
    #
    # @param indexable Object to index
    # @param bulk_connection Client bulk connection object.  See index_async_job.rb
    def self.unindex(indexable,bulk_connection = nil)
      if Elastic::Rebound.config[:object_types][indexable.class.name.to_sym]
        Elastic::Rebound.config[:object_types][indexable.class.name.to_sym][:indexers].each_pair do |idxer,value|
          adapter = idxer.new
          if adapter.async?(indexable) && !@@testing_mode   &&   !bulk_connection
            Elastic::Rebound::IndexJob.perform_async(adapter.class.name, indexable.id, indexable.class.name,true)
          else
            adapter.unindex(indexable.id,@@testing_mode,bulk_connection)
          end
        end
      end
    end

    # Given a object to index it will find that object type in the configration and
    # add or update it in the index
    #
    # @param indexable Object to index
    # @param bulk_connection Client bulk connection object.  See index_async_job.rb
  	def self.index(indexable,bulk_connection = nil)
      if Elastic::Rebound.config[:object_types][indexable.class.name.to_sym]
        Elastic::Rebound.config[:object_types][indexable.class.name.to_sym][:indexers].each_pair do |idxer,value|
          adapter = idxer.new
          if adapter.async?(indexable) && !@@testing_mode &&  !bulk_connection
            Elastic::Rebound::IndexJob.perform_async( adapter.class.name, indexable.id, indexable.class.name,false)
          else
            data = adapter.index_data(indexable)
            adapter.index(data,@@testing_mode,bulk_connection)
            adapter.after_index(indexable,bulk_connection)
          end
        end
      end
    end


    def self.flush_index(kind)
       if Elastic::Rebound.config[:object_types][kind.name.to_sym]
         Elastic::Rebound.config[:object_types][kind.name.to_sym][:indexers].each_pair do |idxer,value|
           adapter = idxer.new
           adapter.refresh_index
         end
       end
     end



    def self.reindex_all(kind_to_index,options = {})
      adaptors = []

      bulk_client =  Elastic::Rebound.client

      Elastic::Rebound.config[:object_types][kind_to_index.name.to_sym][:indexers].each_pair do |idxer,value|
        adaptors << idxer.new
      end

      adaptors.each do |a|
        a.create_index
      end

      kind_to_index.find_in_batches(options) do  |group|
        index_data = []

        bulk_client.bulk do |batch|
          group.each do |o|

            adaptors.each do |a|
              a.index(a.index_data(o),false,batch)
            end
          end
        end
      end

      adaptors.each do |a|
        a.refresh_index
      end


    end

    ESCAPE_LUCENE_REGEX = /
      ( [-+!\(\)\{\}\[\]^"~*?:\\\/] # A special character
        | &&                      # Boolean &&
        | \|\|                    # Boolean ||
      )/x.freeze

    # Escapes per https://lucene.apache.org/core/3_6_0/queryparsersyntax.html#Escaping
    def self.escape_query(query)
      query.gsub(ESCAPE_LUCENE_REGEX) { |m| "\\#{m}" }
    end

  end
end
