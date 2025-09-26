# frozen_string_literal: true

class CreatePersonalIdentifierAssignments < ActiveRecord::Migration[7.2]

  def up
    create_table :personal_identifier_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :personal_identifier, null: false, foreign_key: true
      t.tstzrange :period,               null: false # [start, end) в UTC
      t.timestamps
    end
    add_index :personal_identifier_assignments, %i[personal_identifier_id period],
              using: :gist, name: 'idx_pia_ident_period_gist'
    add_index :personal_identifier_assignments, %i[user_id period],
              using: :gist, name: 'idx_pia_user_period_gist'

    # Запрещаем пересекающиеся периоды:
    # 1) один и тот же номер не может принадлежать двум людям одновременно
    add_exclusion_constraint :personal_identifier_assignments,
                             'personal_identifier_id WITH =, period WITH &&',
                             using: :gist, name: 'excl_pia_ident_overlap'

    # 2) у одного пользователя не может быть двух разных номеров одновременно
    add_exclusion_constraint :personal_identifier_assignments,
                             'user_id WITH =, period WITH &&',
                             using: :gist, name: 'excl_pia_user_overlap'
  end

  def down
    drop_table :personal_identifier_assignments
  end

end
