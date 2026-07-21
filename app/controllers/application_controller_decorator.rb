# frozen_string_literal: true

module ApplicationControllerDecorator
  extend ActiveSupport::Concern

  prepended do
    before_action :set_current_user
  end

  private

  def set_current_user
    HykuKnapsack::Current.user = current_user
  end
end

ApplicationController.prepend(ApplicationControllerDecorator)
