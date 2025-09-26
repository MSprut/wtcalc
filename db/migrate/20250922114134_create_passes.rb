# frozen_string_literal: true

class CreatePasses < ActiveRecord::Migration[7.2]

  def up
    create_table :passes do |t|
      t.references :user, foreign_key: true
      t.datetime :happened_at,  null: false
      t.string   :direction,    null: false # 'in' / 'out'
      t.citext   :door
      t.citext   :comment
      t.citext   :calculation_basis
      t.citext   :zone
      t.jsonb    :raw, null: false, default: {}
      t.references :import_file, foreign_key: true
      t.timestamps
    end
    add_index :passes, :happened_at
    add_index :passes, %i[user_id happened_at]
    add_check_constraint :passes, "direction IN ('in','out')", name: 'chk_passes_direction'
  end

  def down
    drop_table :passes
  end

end
