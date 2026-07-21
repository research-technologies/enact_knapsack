# frozen_string_literal: true

module HykuKnapsack
  module ActiveJobUser
    extend ActiveSupport::Concern

    included do
      attr_accessor :user_id
    end

    class_methods do
      def deserialize(job_data)
        super.tap do |job|
          job.user_id = job_data['user_id']
        end
      end
    end

    def serialize
      super.merge('user_id' => HykuKnapsack::Current.user&.id)
    end

    def perform_now
      previous = HykuKnapsack::Current.user
      HykuKnapsack::Current.user = user_id ? ::User.find_by(id: user_id) : nil
      super
    ensure
      HykuKnapsack::Current.user = previous
    end
  end
end
