# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 to add an adaptive HLS ladder after the normal video
# derivatives, gated on ffmpeg + the per-tenant :hls_streaming feature.
#
# Named *HlsDecorator, not the bare *Decorator, on purpose: Hyku already defines
# Hyrax::FileSetDerivativesServiceDecorator for this class, and the knapsack app is
# Zeitwerk-managed, so a second file defining that same constant would fail to boot.
module Hyrax
  module FileSetDerivativesServiceHlsDecorator
    def create_derivatives(filename)
      super
      return unless video? && hls_streaming_enabled?

      Hyrax::HlsDerivativeService.new(file_set:).generate(filename)
    end

    private

    def video?
      Array(Hyrax.config.derivative_mime_type_mappings[:video]).include?(mime_type)
    end

    def hls_streaming_enabled?
      Hyrax.config.enable_ffmpeg && Flipflop.enabled?(:hls_streaming)
    end
  end
end

Hyrax::FileSetDerivativesService.prepend(Hyrax::FileSetDerivativesServiceHlsDecorator)
