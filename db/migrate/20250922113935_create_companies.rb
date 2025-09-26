# frozen_string_literal: true

class CreateCompanies < ActiveRecord::Migration[7.2]

  def change
    create_table :companies do |t|
      t.citext :name, null: false
      t.string :code
      t.timestamps
    end
    add_index :companies, :name, unique: true
  end

end
