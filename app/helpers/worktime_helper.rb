# frozen_string_literal: true

module WorktimeHelper

  # Глобальный дефолт (user_id=nil, on_date=nil)
  def global_lunch_minutes
    LunchBreak.global.first&.minutes.to_i
  end

  # Персональный дефолт для пользователя (on_date=nil), с падением на глобальный
  def user_default_lunch_minutes(user)
    LunchBreak.where(user_id: user.id, on_date: nil).pick(:minutes) || global_lunch_minutes
  end

  # Обед для конкретного дня
  def lunch_minutes_for(user, date)
    LunchBreak.for(user, date).to_i
  end

end
