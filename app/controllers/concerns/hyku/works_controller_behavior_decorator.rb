# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 to fix a double render bug for the iiif manifest

module Hyku
  module WorksControllerBehaviorDecorator
    def manifest
      super unless performed?
    end
  end
end

Hyku::WorksControllerBehavior.prepend(Hyku::WorksControllerBehaviorDecorator)
