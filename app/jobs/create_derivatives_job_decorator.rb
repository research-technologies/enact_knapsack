# frozen_string_literal: true

# OVERRIDE Hyku – fix video?/audio? NoMethodError in Valkyrie mode (HYRAX_SKIP_WINGS=true).
# Hyrax::FileSet is a pure Valkyrie resource and does not inherit the Wings/ActiveFedora
# file-type predicate methods. Fall back to the MIME type from the Solr document.
# Remove when: Hyrax::FileSet exposes video?/audio? natively in Valkyrie mode.
module CreateDerivativesJobDecorator
  def perform(file_set, file_id, filepath = nil)
    return super if is_a?(CreateLargeDerivativesJob)
    return super unless large_media_file_set?(file_set)

    CreateLargeDerivativesJob.perform_later(*arguments)
    true
  end

  private

  def large_media_file_set?(file_set)
    if file_set.respond_to?(:video?)
      file_set.video? || file_set.audio?
    else
      mime = SolrDocument.find(file_set.id.to_s)["mime_type_ssi"].to_s
      mime.start_with?('video/', 'audio/')
    end
  end
end

CreateDerivativesJob.prepend(CreateDerivativesJobDecorator)
