module Elastic
  module Rebound
    class IndexJob

      @queue = :reports

      #
      # @param adaptor_class Class used to index the object.
      # @param object_id Active record object id
      # @param object_class Type of class to be indexed
      #
      def self.perform(adaptor_class, object_id, object_class, delete_from_index)
        adp_klass = adaptor_class.constantize.new

        if delete_from_index
          adp_klass.unindex(object_id, delete_from_index)
        else

          klass = object_class.constantize
          indexable = klass.find_by_id(object_id)

          # Make sure it still exist.
          if indexable
            data = adp_klass.index_data(indexable)
            adp_klass.index(data)
            adp_klass.after_index(indexable)
          end

        end

      end
    end
  end
end