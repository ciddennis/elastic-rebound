require 'elasticsearch'
require "elastic/rebound/version"
require "elastic/rebound/adaptor"
require "elastic/rebound/index_job"
require "elastic/rebound/index_async_job"
require "elastic/rebound/result"
require "elastic/rebound/simple_strategy"
require "elastic/rebound/strategy"
require "elastic/rebound/active_callback"


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
      Elasticsearch::Client.new({url: Elastic::Rebound.config[:elastic_search_url]}.merge(options))
    end

    # Given a object to index it will find that object type in the configration and
    # remove it from the index.
    #
    # @param indexable Object to index
    # @param bulk_connection Client bulk connection object.  See index_async_job.rb
    def self.unindex(indexable,bulk_connection = nil)
      clazz = Elastic::Rebound.object_class(indexable)
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
      clazz = Elastic::Rebound.object_class(indexable.class)

      if Elastic::Rebound.config[:object_types][clazz.name.to_sym]
        Elastic::Rebound.config[:object_types][clazz.name.to_sym][:indexers].each_pair do |idxer,value|
          adapter = idxer.new
          if adapter.async?(indexable) && !@@testing_mode &&  !bulk_connection
            Elastic::Rebound::IndexJob.perform_async( adapter.class.name, indexable.id, clazz.name,false)
          else
            data = adapter.index_data(indexable)
            adapter.index(data,@@testing_mode,bulk_connection)
            adapter.after_index(indexable,bulk_connection)
          end
        end
      end
    end


    def self.flush_index(kind)
      clazz = Elastic::Rebound.object_class(kind)
       if Elastic::Rebound.config[:object_types][clazz.name.to_sym]
         Elastic::Rebound.config[:object_types][clazz.name.to_sym][:indexers].each_pair do |idxer,value|
           adapter = idxer.new
           adapter.refresh_index
         end
       end
     end



    # Based on the class sent it we will find out if it is an active record class
    # if it is then we will find the base class and return that.  That is
    # really what we want to index.
    def self.object_class(clazz)
      the_class = clazz

      unless clazz.kind_of?(Class)
        the_class = clazz.class
      end

      if defined?(ActiveRecord::Base)
        return the_class.base_class

      end

      the_class
    end

    def self.reindex_all(kind_to_index,options = {})
      adaptors = []

      bulk_client =  Elastic::Rebound.client

      clazz = Elastic::Rebound.object_class(kind_to_index)

      Elastic::Rebound.config[:object_types][clazz.name.to_sym][:indexers].each_pair do |idxer,value|
        adaptors << idxer.new
      end

      adaptors.each do |a|
        a.create_index
      end

      kind_to_index.find_in_batches(options) do  |group|
        index_data = []

        # bulk_client.bulk do |batch|
          group.each do |o|

            adaptors.each do |a|
              a.index(a.index_data(o),false)
            end
          end
        # end
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
