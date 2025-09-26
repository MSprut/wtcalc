# frozen_string_literal: true

class CreateUserDivisionMemberships < ActiveRecord::Migration[7.2]

  def up
    create_table :user_division_memberships do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :division, null: false, foreign_key: true
      t.tstzrange  :period,   null: false # [start, end)
      t.timestamps
    end
    add_index :user_division_memberships, %i[user_id period], using: :gist
    add_exclusion_constraint :user_division_memberships,
                             'user_id WITH =, period WITH &&',
                             using: :gist, name: 'excl_udm_user_overlap'
  end

  def down
    drop_table :user_division_memberships
  end

end
