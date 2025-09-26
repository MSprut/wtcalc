# frozen_string_literal: true

class Division < ApplicationRecord

  # belongs_to :company, optional: true
  has_many :company_divisions, dependent: :destroy
  has_many :companies, through: :company_divisions

  has_many :user_division_memberships, dependent: :destroy
  has_many :users, through: :user_division_memberships

  # удобно получать «текущих» пользователей, если у User есть current_division_id
  has_many :current_users,
           class_name: 'User',
           foreign_key: :current_division_id,
           inverse_of: :current_division

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :recent,  -> { order(created_at: :desc) }
  scope :by_name, ->(q) { q.present? ? where('lower(name) LIKE ?', "%#{q.downcase.strip}%") : all }

end
