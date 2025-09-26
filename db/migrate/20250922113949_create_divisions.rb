# frozen_string_literal: true

class CreateDivisions < ActiveRecord::Migration[7.2]

  def up
    create_table :divisions do |t|
      t.citext :name, null: false
      t.timestamps
    end
    # add_index :divisions, :name, unique: true
    add_index :divisions, 'lower(name)', unique: true, name: 'idx_divisions_name_lower_unique'

    # add_index :divisions, %i[company_id name], unique: true, name: 'idx_divisions_company_name_unique'
  end

  def down
    drop_table :divisions
  end

end
