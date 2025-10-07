class CompanyDivision < ApplicationRecord

  belongs_to :company
  belongs_to :division

  validates :company_id,  presence: true
  validates :division_id, presence: true
  validates :division_id, uniqueness: { scope: :company_id }

end
