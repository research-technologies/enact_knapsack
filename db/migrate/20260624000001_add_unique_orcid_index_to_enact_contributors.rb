# frozen_string_literal: true

# Unique ORCID when present: a partial index (`WHERE orcid IS NOT NULL`) leaves
# ORCID-less contributors unconstrained, so the column stays optional. Replaces
# the original non-unique lookup index.
class AddUniqueOrcidIndexToEnactContributors < ActiveRecord::Migration[7.2]
  def up
    # Existing rows saved a missing ORCID as '' before the model normalized blank
    # to NULL; collapse them so they don't collide under the new unique index.
    execute "UPDATE enact_contributors SET orcid = NULL WHERE orcid = ''"

    remove_index :enact_contributors, :orcid
    add_index :enact_contributors, :orcid, unique: true, where: 'orcid IS NOT NULL'
  end

  def down
    remove_index :enact_contributors, :orcid
    add_index :enact_contributors, :orcid
  end
end
