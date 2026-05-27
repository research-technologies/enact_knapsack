# frozen_string_literal: true

# Defensive shim for `IIIFManifest::V3::ManifestBuilder::ThumbnailBuilder#reduction_ratio`.
# The upstream method does `width <= max_edge` (and same for height), which
# raises NoMethodError when characterization hasn't populated width/height on
# the file metadata - e.g. immediately after seed, before FITS has run, or
# when FITS is unreachable. Without this guard the entire IIIF manifest
# endpoint returns 500 and Universal Viewer can't render at all.
#
# When dimensions are missing, fall back to a 1.0 reduction (i.e. "use the
# image at native size"), which lets the rest of the manifest render. The
# catalog/show page handles its own thumbnail via the Solr `thumbnail_path_ss`,
# so this is only about the IIIF document.
Rails.application.config.to_prepare do
  next unless defined?(IIIFManifest::V3::ManifestBuilder::ThumbnailBuilder)

  IIIFManifest::V3::ManifestBuilder::ThumbnailBuilder.class_eval do
    next if private_method_defined?(:reduction_ratio_with_enact_guard)

    alias_method :reduction_ratio_without_enact_guard, :reduction_ratio
    private :reduction_ratio_without_enact_guard

    define_method(:reduction_ratio) do
      width  = display_content.width
      height = display_content.height
      return 1 if width.nil? || height.nil?

      reduction_ratio_without_enact_guard
    end
    alias_method :reduction_ratio_with_enact_guard, :reduction_ratio
    private :reduction_ratio, :reduction_ratio_with_enact_guard
  end
end
