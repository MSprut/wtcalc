# frozen_string_literal: true

class ImportFile < ApplicationRecord

  has_many :passes, dependent: :nullify

  validates :filename, presence: true
  validates :checksum, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }

  def to_s = filename

end
