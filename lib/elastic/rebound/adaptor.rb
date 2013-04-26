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
      #
      def index(data, refresh = false)
        if data.kind_of?(Array)
          Elastic::Rebound.client.bulk do
            data.each do |d|
              Elastic::Rebound.client.index(d, :type => @object_name, :index => @index_name, :id => d[:id])
            end
          end
        else
          Elastic::Rebound.client.index(data, :type => @object_name, :index => @index_name, :id => data[:id])
        end

        refresh_index if refresh
      end

      #
      # Remove the object with the given id from the index
      #
      # @param object_id id of object to remove
      # @param refresh Call refresh on elastic search after requesting indexing.
      #
      def unindex(object_id, refresh = false)
        Elastic::Rebound.client.delete(object_id, :type => @object_name, :index => @index_name)
        refresh_index if refresh
      end

      #
      # Tell elastic search to refresh its search index so data is available right away.
      #
      def refresh_index
        Elastic::Rebound.client.refresh({:index => @index_name})
      end

      #
      # Should indexing be done in a background job?
      #
      def async?
        false
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
        Elastic::Rebound.client.update_mapping(mapping, {:index => @index_name, :type => @object_name})
      end

      #
      # Deletes the index and mapping then recreates the index with out the mapping.
      #
      def reset_index_and_mapping

        if Elastic::Rebound.client.index_exists?(@index_name)
          Elastic::Rebound.client.delete_mapping({:index => @index_name, :type => @object_name}) rescue nil
          Elastic::Rebound.client.delete_index @index_name rescue nil
        end


      end
    end
  end
end
