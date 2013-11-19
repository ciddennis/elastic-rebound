module Elastic
  module Rebound
    class IndexAsyncJob
      require "sidekiq"
      include Sidekiq::Worker

      sidekiq_options :queue => :medium, :backtrace => true

      #
      # This job take a has with any number of class name pointing to an array of object ids.
      # If the id exist it will update the index with the new data. If it can not be found in the
      # database it will remove them from the index.
      #
      # @param objects  {"class_name" => [id,id,id]}
      # For Example {"Applet" => [3,4,5,4,4,5,6] }
      #
      def perform(objects)

        bulk_client =  Elastic::Rebound.client

        objects.each_pair do |class_name, ids|
          bulk_client.bulk do |batch|

            clazz = Elastic::Rebound.object_class(class_name.constantize)
            if Elastic::Rebound.config[:object_types][clazz.to_s.to_sym]
              Elastic::Rebound.config[:object_types][clazz.to_s.to_sym][:indexers].each_pair do |idxer, value|

                adapter = idxer.new
                klass = clazz
                indexables = klass.where(:id => ids)

                index_ids = []
                # Make sure it still exist.
                indexables.each do |indexable|
                  index_ids << indexable.id
                  data = adapter.index_data(indexable)
                  adapter.index(data,false,batch)
                  adapter.after_index(indexable,batch)
                end

                notfound = ids - index_ids
                notfound.each do |deletethis|
                  adapter.unindex(deletethis,false,batch)
                end

              end
            end
          end
        end

      end


    end
  end
end
