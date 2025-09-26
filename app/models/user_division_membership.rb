# frozen_string_literal: true

class UserDivisionMembership < ApplicationRecord

  belongs_to :user
  belongs_to :division

  validates :period, presence: true

  scope :active_at, ->(t) { where('period @> ?::timestamptz', t) }
  scope :active_now, -> { active_at(Time.current) }

end
