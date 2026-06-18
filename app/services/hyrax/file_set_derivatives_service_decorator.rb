# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 – copy the source file to the IIIF S3 bucket after
# each derivative creation run, keyed by SHA1 so the serverless-iiif Lambda can
# serve it.
# Remove when: Hyrax supports a configurable post-derivative upload hook.
module Hyrax
  module FileSetDerivativesServiceDecorator
  end
end

Hyrax::FileSetDerivativesService.prepend Enact::IiifS3CopyBehavior
