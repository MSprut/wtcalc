# frozen_string_literal: true

class ImportFile < ApplicationRecord

  has_many :passes, dependent: :delete_all
  # если позже добавить FK в другие таблицы:
  # has_many :personal_identifier_assignments, dependent: :delete_all
  # has_many :user_division_memberships,      dependent: :delete_all

  validates :filename, presence: true
  validates :checksum, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }

  def to_s = filename

end
