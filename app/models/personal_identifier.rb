# frozen_string_literal: true

class PersonalIdentifier < ApplicationRecord

  has_many :personal_identifier_assignments, dependent: :destroy
  has_many :users, through: :personal_identifier_assignments

  validates :value, :normalized_value, presence: true
  validates :normalized_value, uniqueness: true

  before_validation :normalize!

  def normalize!
    self.normalized_value = value.to_s.gsub(/[^0-9A-Za-z]/, '').upcase.strip
  end

end
