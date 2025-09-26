# frozen_string_literal: true

class CreateCores < ActiveRecord::Migration[7.2]

  def up
    enable_extension 'citext'
    enable_extension 'btree_gist'   # для EXCLUDE по диапазонам
    enable_extension 'pg_trgm'      # быстрый поиск по ФИО
  end

end
