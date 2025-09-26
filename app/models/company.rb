# frozen_string_literal: true

class Company < ApplicationRecord

  # has_many :divisions, dependent: :nullify
  has_many :company_divisions, dependent: :destroy
  has_many :divisions, through: :company_divisions

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :by_name, ->(q) { q.present? ? where('lower(name) LIKE ?', "%#{q.downcase.strip}%") : all }

end
