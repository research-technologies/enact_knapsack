# frozen_string_literal: true

# OVERRIDES BULKRAX v9.1.0
#
# Empty 'id' in import is parsed to be id: "" and "" is truthy so an object not found error is thrown.
# Check for id == "" and treat as id == nil
module Bulkrax
  module HasMatchersDecorator
    # Overriding the entire method to inject validation against id: ""
    def add_metadata(node_name, node_content, index = nil)
      field_to(node_name).each do |name|
        matcher = self.class.matcher(name, mapping[name].symbolize_keys) if mapping[name] # the field matched to a pre parsed value in application_matcher.rb
        object_name = get_object_name(name) || false # the "key" of an object property. e.g. { object_name: { alpha: 'beta' } }
        multiple = multiple?(name) # the property has multiple values. e.g. 'letters': ['a', 'b', 'c']
        object_multiple = object_name && multiple?(object_name) # the property's value is an array of object(s)

        next unless field_supported?(name) || (object_name && field_supported?(object_name))

        if object_name
          Rails.logger.info("Bulkrax Column automatically matched object #{node_name}, #{node_content}")
          init_object_container(object_name, object_multiple)
        end

        value = if matcher
                  result = matcher.result(self, node_content)
                  matched_metadata(multiple, name, result, object_multiple)
                elsif multiple
                  Rails.logger.info("Bulkrax Column automatically matched #{node_name}, #{node_content}")
                  multiple_metadata(node_content)
                else
                  Rails.logger.info("Bulkrax Column automatically matched #{node_name}, #{node_content}")
                  single_metadata(node_content)
                end
        unless name == 'id' && value == ''
          object_name.present? ? set_parsed_object_data(object_multiple, object_name, name, index, value) : set_parsed_data(name, value)
        end
      end
    end
  end
end

Bulkrax::HasMatchers.prepend(Bulkrax::HasMatchersDecorator)
