# frozen_string_literal: true

# OVERRIDE IiifPrint v3.0.12 – copy the source file to the IIIF S3 bucket after
# each derivative creation run, keyed by SHA1 so the serverless-iiif Lambda can
# serve it.
# Remove when: IiifPrint supports a configurable post-derivative upload hook.
module IiifPrint
  module TenantConfig
    module DerivativeServiceDecorator
    end
  end
end

IiifPrint::TenantConfig::DerivativeService.prepend Enact::IiifS3CopyBehavior
