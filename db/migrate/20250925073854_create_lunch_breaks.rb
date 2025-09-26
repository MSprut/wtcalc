class CreateLunchBreaks < ActiveRecord::Migration[7.2]

  def up
    create_table :lunch_breaks do |t|
      t.references :user, foreign_key: true, null: true     # NULL => не привязано к пользователю
      t.date       :on_date, null: true                     # NULL => «по умолчанию» для данного user или глобально
      t.integer    :minutes, null: false, default: 0
      t.timestamps
    end

    # уникально для «конкретный пользователь + конкретный день»
    add_index :lunch_breaks, %i[user_id on_date], unique: true, name: 'idx_lb_user_ondate_unique'

    # уникально «персональный дефолт» (user_id, on_date=NULL) — по одному на пользователя
    add_index :lunch_breaks, :user_id, unique: true, where: 'on_date IS NULL', name: 'idx_lb_user_default_unique'

    # единственная глобальная запись (user_id=NULL, on_date=NULL)
    execute <<~SQL.squish
      CREATE UNIQUE INDEX idx_lb_global_default_one
      ON lunch_breaks ((1))
      WHERE user_id IS NULL AND on_date IS NULL;
    SQL

    # если у тебя раньше было users.lunch_break_minutes — мягкий перенос:
    return unless column_exists?(:users, :lunch_break_minutes)

    execute <<~SQL.squish
      INSERT INTO lunch_breaks (user_id, on_date, minutes, created_at, updated_at)
      SELECT id, NULL, COALESCE(lunch_break_minutes,0), NOW(), NOW() FROM users
      WHERE lunch_break_minutes IS NOT NULL;
    SQL
    remove_column :users, :lunch_break_minutes
  end

  def down
    drop_table :lunch_breaks
  end

end
