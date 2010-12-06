# Copyright 2010 Sean Cribbs, Sonian Inc., and Basho Technologies, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
require 'ripple'

module Ripple
  module Document
    module Persistence
      extend ActiveSupport::Concern
      extend ActiveSupport::Autoload

      module ClassMethods

        # Instantiates a new record, applies attributes from a block, and saves it
        def create(attrs={}, &block)
          new(attrs, &block).tap {|s| s.save }
        end

        # Destroys all records one at a time.
        # Place holder while :delete to bucket is being developed.
        def destroy_all
          all(&:destroy)
        end

        attr_writer :quorums
        alias_method "set_quorums", "quorums="

        def quorums
          @quorums ||= {}
        end
      end

      module InstanceMethods
        # @private
        def initialize
          super
          @new = true
        end

        # Determines whether this is a new document.
        def new?
          @new || false
        end

        # Updates a single attribute and then saves the document
        # NOTE: THIS SKIPS VALIDATIONS! Use with caution.
        # @return [true,false] whether the document succeeded in saving
        def update_attribute(attribute, value)
          send("#{attribute}=", value)
          save(:validate => false)
        end

        # Writes new attributes and then saves the document
        # @return [true,false] whether the document succeeded in saving
        def update_attributes(attrs)
          self.attributes = attrs
          save
        end

        # Saves the document in Riak.
        # @return [true,false] whether the document succeeded in saving
        def save(*args)
          robject.key = key if robject.key != key
          robject.data = attributes_for_persistence
          robject.store(self.class.quorums.slice(:w,:dw))
          self.key = robject.key
          @new = false
          true
        rescue Riak::FailedRequest
          false
        end

        # Reloads the document from Riak
        # @return self
        def reload
          return self if new?
          robject.reload(:force => true)
          @robject.data.except("_type").each { |key, value| send("#{key}=", value) }
          self
        end

        # Deletes the document from Riak and freezes this instance
        def destroy
          robject.delete(self.class.quorums.slice(:rw)) unless new?
          freeze
          true
        rescue Riak::FailedRequest
          false
        end

        # Freezes the document, preventing further modification.
        def freeze
          @attributes.freeze; super
        end

        attr_writer :robject

        def robject
          @robject ||= Riak::RObject.new(self.class.bucket, key).tap do |obj|
            obj.content_type = "application/json"
          end
        end

        private
        def attributes_for_persistence
          attributes.merge("_type" => self.class.name)
        end
      end
    end
  end
end
