# frozen_string_literal: true

# Enact::Contributor — a lightweight, editable contributor profile record
# (a person or organization), independent of the Hyrax User (a contributor may
# have no login and no email). Works link to contributors via the `contributors`
# `linked_record` compound subproperty.
#
# Typed single table with a JSON attribute blob: stable structural columns plus
# `metadata` for the type-varying / extensible attributes (e.g. affiliation,
# and ror until promoted to a column when organizations are exercised). Integer
# PK + `user_id` to match the host app's `users` (id: :serial). `user_id` is
# reserved for the future claim flow and is unused in Phase 1.
class CreateEnactContributors < ActiveRecord::Migration[7.2]
  def change
    create_table :enact_contributors do |t|
      t.string :display_name, null: false
      t.string :agent_type, null: false, default: 'person'
      t.string :orcid
      # Reserved for the future claim flow (links a claimed contributor to a
      # Hyrax User). Nullable + unused in Phase 1; no FK constraint yet so the
      # claim model can decide linkage semantics later.
      t.integer :user_id
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :enact_contributors, :display_name
    add_index :enact_contributors, :orcid
    add_index :enact_contributors, :user_id
    add_index :enact_contributors, :agent_type
  end
end
