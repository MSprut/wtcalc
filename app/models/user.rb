# frozen_string_literal: true

class User < ApplicationRecord

  PIN_SIZE = 4

  enum :role, { user: 0, manager: 1, admin: 2 }

  belongs_to :current_division, class_name: 'Division', optional: true

  has_many :personal_identifier_assignments, dependent: :destroy
  has_many :personal_identifiers, through: :personal_identifier_assignments

  has_many :user_division_memberships, dependent: :destroy
  has_many :divisions, through: :user_division_memberships

  has_many :passes, dependent: :nullify
  has_many :lunch_breaks, dependent: :destroy

  validates :last_name, :first_name, :auth_login, presence: true
  validates :auth_login, presence: true, uniqueness: { case_sensitive: false }

  # PIN как отдельный секрет (второй фактор, короткий)
  has_secure_password :pin, validations: false # требует колонку pin_digest
  validates :pin, length: { is: PIN_SIZE }, allow_nil: true

  def full_name
    [last_name, first_name, middle_name].compact.join(' ')
  end

end
