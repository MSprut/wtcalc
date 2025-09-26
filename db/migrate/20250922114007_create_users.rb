# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.2]

  def up
    create_table :users do |t|
      t.citext :last_name,  null: false
      t.citext :first_name, null: false
      t.citext :middle_name
      t.date   :dob
      t.references :current_division, foreign_key: { to_table: :divisions } # удобно для «текущего» состояния
      t.citext :position
      t.string :auth_login, null: false
      t.string :pin_digest # bcrypt для PIN
      t.integer :role, null: false, default: 0
      t.timestamps
    end
    add_index :users, :auth_login, unique: true
    execute <<~SQL.squish
      CREATE INDEX idx_users_fullname_trgm
      ON users
      USING gin (
        (
          COALESCE(last_name::text,'') || ' ' ||
          COALESCE(first_name::text,'') || ' ' ||
          COALESCE(middle_name::text,'')
        ) gin_trgm_ops
      );
    SQL
  end

  def down
    execute 'DROP INDEX IF EXISTS idx_users_fullname_trgm;'
    drop_table :users
  end

end
