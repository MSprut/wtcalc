# frozen_string_literal: true

class CreateCompanyDivisions < ActiveRecord::Migration[7.2]

  def up
    create_table :company_divisions do |t|
      t.references :company,  null: false, foreign_key: true
      t.references :division, null: false, foreign_key: true
      t.timestamps
    end
    add_index :company_divisions, %i[company_id division_id],
              unique: true, name: 'idx_company_divisions_unique'
  end

  def down
    drop_table :company_divisions
  end

end
