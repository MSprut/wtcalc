# frozen_string_literal: true

class CreateImportFiles < ActiveRecord::Migration[7.2]

  def up
    create_table :import_files do |t|
      t.string   :filename,  null: false
      t.string   :checksum,  null: false
      t.integer  :rows_count, default: 0
      t.timestamps
    end
    add_index :import_files, :checksum, unique: true
  end

  def down
    drop_table :import_files
  end

end
