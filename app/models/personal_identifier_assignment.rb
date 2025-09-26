# frozen_string_literal: true

class PersonalIdentifierAssignment < ApplicationRecord

  belongs_to :user
  belongs_to :personal_identifier

  validates :period, presence: true
  # удобные скоупы
  scope :active_at, ->(t) { where('period @> ?::timestamptz', t) }
  scope :active_now, -> { active_at(Time.current) }

end
