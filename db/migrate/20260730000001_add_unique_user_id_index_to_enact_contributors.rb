# frozen_string_literal: true

class AddUniqueUserIdIndexToEnactContributors < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE enact_contributors SET user_id = NULL
      WHERE user_id IS NOT NULL
        AND id NOT IN (
          SELECT MIN(id) FROM enact_contributors
          WHERE user_id IS NOT NULL GROUP BY user_id
        )
    SQL

    remove_index :enact_contributors, :user_id
    add_index :enact_contributors, :user_id, unique: true, where: 'user_id IS NOT NULL'
  end

  def down
    remove_index :enact_contributors, :user_id
    add_index :enact_contributors, :user_id
  end
end
