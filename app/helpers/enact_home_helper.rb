# frozen_string_literal: true

# Reaches views through HykuKnapsack::ApplicationHelper, which Hyku's own ApplicationHelper
# includes.
module EnactHomeHelper
  def enact_share_work?
    @presenter&.display_share_button? && !Flipflop.read_only?
  end

  def enact_share_work_target
    return [hyrax.my_works_path, {}] unless signed_in?

    deposit_new_work_target(many: @presenter.create_many_work_types?,
                            first_type: @presenter.first_work_type)
  end
end
