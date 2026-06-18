# frozen_string_literal: true

# OVERRIDE Hyku v5.x – include IIIF CloudFront signed-cookie support on every
# HTML request so browsers can access CloudFront-protected IIIF image resources.
# Remove when: Hyku supports a first-class IIIF authentication hook.
module ApplicationControllerDecorator
end

ApplicationController.include HykuKnapsack::IiifCloudfrontCookies
