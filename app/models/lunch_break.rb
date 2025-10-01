# frozen_string_literal: true

class LunchBreak < ApplicationRecord

  belongs_to :user, optional: true

  validates :minutes, numericality: { greater_than_or_equal_to: 0, less_than: 8 * 60 }

  scope :global, -> { where(user_id: nil, on_date: nil) }

  scope :for_range, ->(user_ids, from, to) { where(user_id: user_ids, on_date: from..to) }
  scope :user_defaults, ->(user_ids) { where(user_id: user_ids, on_date: nil) }
  scope :global_default, -> { find_by(user_id: nil, on_date: nil)&.minutes }

  def self.global_minutes
    global.first&.minutes.to_i
  end

  def self.set_global!(minutes)
    rec = global.first_or_initialize
    rec.minutes = minutes.to_i
    rec.save!
    rec
  end

  # Приоритет: user+date → user default → global → 0
  def self.for(user, date)
    where(user_id: user.id, on_date: date).pick(:minutes) ||
      where(user_id: user.id, on_date: nil).pick(:minutes) ||
      global_minutes
  end

end
