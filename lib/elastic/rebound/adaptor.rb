require "elastic/rebound"

module Elastic
  module Rebound
    class Adaptor
      #
      # @param index_name   Name of index
      # @param object_type  Object type being mapped
      #
      def initialize(index_name, object_type)
        @index_name = index_name
        @object_name = object_type
      end

      #
      # Returns a hash that maps to the defined index mapping.  All index objects must
      # have at least an id element.
      #
      # @param indexable Object to be indexed.
      #
      # @return { :id => indexable.id, :title => indexable.title }
      #
      def define_index
        raise new Exception("You must implement the define index method.")
      end

      #
      # Returns a hash that maps to the defined index mapping.  All index objects must
      # have at least an id element.
      #
      # @param indexable Object to be indexed.
      #
      # @return { :id => indexable.id, :title => indexable.title }
      #
      def index_data(indexable)
        raise new Exception("You must implement the index data method.")
      end

      #
      # Send the passing in array of object to elastic search for indexing.
      #
      # @param data Array of hashes returned by the index_data method
      # @param refresh Call refresh on elastic search after requesting indexing.
      # @param batch_connection If passed in the code  will ignore refresh and will use the passed in connection to batch request
      # see the index_async_job.rb for example of how to use batch_connection.
      #
      def index(data, refresh = false,batch_connection = nil)
        connection  =  batch_connection ||  Elastic::Rebound.client
        data = [data].flatten

        data.each do |d|
          connection.index(index: @index_name, :id => d[:id], type: @object_name, body: d, refresh: refresh)
        end

      end

      #
      # Remove the object with the given id from the index
      #
      # @param object_id id of object to remove
      # @param refresh Call refresh on elastic search after requesting indexing.
      # @param batch_connection If passed in the code  will ignore refresh and will use the passed in connection to batch request
      #
      def unindex(object_id, refresh = false,batch_connection = nil)
        connection  =  batch_connection ||  Elastic::Rebound.client
        if object_id
          connection.delete(index: @index_name, type: @object_name, id: object_id, refresh: refresh)
        end
      end

      #
      # Tell elastic search to refresh its search index so data is available right away.
      #
      def refresh_index
        Elastic::Rebound.client.refresh(index: @index_name)
      end

      #
      # Should indexing be done in a background job?
      #
      # @param indexable This is the object about to be index.  This is passed in so that
      # the implementing adaptor has a chance to change based on state.
      #
      def async?(indexable = nil)
        false
      end

      #
      # Provide a call back so that adaptors can do post indexing actions if needed.
      #
      # @param indexable This is the object about to be index.
      #
      def after_index(indexable = nil,batch_connection = nil)

      end

      protected

      #
      # Updates the mapping.
      #
      # @param Hash representing the mapping for this object in the index.
      #
      # @see Elastic search mapping documentation.
      #
      def update_mapping(mapping)
        Elastic::Rebound.client.indices.put_mapping(index: @index_name, type: @object_name, body: mapping)
      end

      #
      # Deletes the index and mapping then recreates the index with out the mapping.
      #
      def reset_index_and_mapping

        if Elastic::Rebound.client.indices.exists(index: @index_name)
          Elastic::Rebound.client.indices.delete_mapping(index: @index_name, type: @object_name) rescue nil
          Elastic::Rebound.client.indices.delete(index: @index_name) rescue nil
        end


      end
    end
  end
end
