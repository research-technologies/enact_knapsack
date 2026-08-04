# frozen_string_literal: true

# Reaches views through HykuKnapsack::ApplicationHelper, which Hyku's own ApplicationHelper
# includes.
module EnactHomeHelper
  NAMED_CONTRIBUTORS = 2
  CARD_BLURB_LENGTH = 150

  def enact_share_work?
    @presenter&.display_share_button? && !Flipflop.read_only?
  end

  def enact_share_work_target
    return [hyrax.my_works_path, {}] unless signed_in?

    deposit_new_work_target(many: @presenter.create_many_work_types?,
                            first_type: @presenter.first_work_type)
  end

  # The context statement is the fallback because description is optional in the profile and empty
  # on most records.
  def enact_card_blurb(presenter, length: CARD_BLURB_LENGTH)
    text = Array(presenter.try(:description)).first.presence ||
           Array(presenter.try(:context_statement)).first
    return if text.blank?

    truncate(enact_plain_text(text), length:, separator: ' ')
  end

  # Hyrax hands back an asset-pipeline placeholder when a work has no thumbnail of its own, and the
  # design asks for the diagonal stripe rather than an icon. Anything that is not a path at all
  # counts as no thumbnail: to_s on a nil would otherwise read as one and render a broken image.
  def enact_thumbnail?(presenter)
    path = presenter.thumbnail_path

    path.is_a?(String) && path.present? && path != Hyrax::ThumbnailPathService.default_image
  end

  # Enact::WorkContributors rather than the presenter's enact_contributor_names: the featured list
  # builds Hyrax::WorkShowPresenter, which is not the class the Hyku presenter decorator extends.
  def enact_contributor_summary(document)
    names = Enact::WorkContributors.new(document).credits.map(&:label).compact_blank
    return if names.empty?

    rest = names.size - NAMED_CONTRIBUTORS
    return names.to_sentence if rest < 1

    # Semicolons, not commas: display names are stored inverted ("Achebe, Ngozi"), so
    # a comma separator reads as twice as many people as there are.
    t('enact.homepage.featured.contributors_and_others',
      names: names.first(NAMED_CONTRIBUTORS).join('; '), count: rest)
  end
end
