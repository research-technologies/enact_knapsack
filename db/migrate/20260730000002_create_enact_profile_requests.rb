# frozen_string_literal: true

# A user's request for a research profile, forming the admin work queue.
class CreateEnactProfileRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :enact_profile_requests do |t|
      t.integer :user_id, null: false
      t.integer :contributor_id
      t.string :status, null: false, default: 'pending'
      t.text :note
      t.text :review_note
      t.integer :reviewed_by_id
      t.datetime :reviewed_at

      t.timestamps
    end

    add_lookup_indexes
    add_pending_request_index
  end

  private

  def add_lookup_indexes
    add_index :enact_profile_requests, :contributor_id
    add_index :enact_profile_requests, :status
    # Ordering the admin queue oldest-first.
    add_index :enact_profile_requests, :created_at
    add_index :enact_profile_requests, %i[user_id status]
  end

  def add_pending_request_index
    add_index :enact_profile_requests, :user_id, unique: true,
                                                 where: "status = 'pending'",
                                                 name: 'index_enact_profile_requests_on_pending_user'
  end
end
