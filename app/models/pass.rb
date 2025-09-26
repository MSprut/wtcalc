# frozen_string_literal: true

class Pass < ApplicationRecord

  belongs_to :user, optional: true
  belongs_to :import_file, optional: true

end
