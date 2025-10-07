# frozen_string_literal: true

class AddProgressToImportFiles < ActiveRecord::Migration[7.2]

  def up
    add_column :import_files, :progress, :integer, default: 0, null: false
    add_column :import_files, :status,   :string,  default: 'Ожидание', null: false
  end

  def down
    remove_column :import_files, :progress
    remove_column :import_files, :status
  end

end
