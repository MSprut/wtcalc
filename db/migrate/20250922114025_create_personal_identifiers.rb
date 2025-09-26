# frozen_string_literal: true

class CreatePersonalIdentifiers < ActiveRecord::Migration[7.2]

  def up
    create_table :personal_identifiers do |t|
      t.string :value,             null: false     # как в источнике
      t.string :normalized_value,  null: false     # нормализованное (сравнение/поиск)
      t.timestamps
    end
    add_index :personal_identifiers, :normalized_value, unique: true
  end

  def down
    drop_table :personal_identifiers
  end

end
