# frozen_string_literal: true

class ImportFileDestroyer

  def initialize(import_file)
    @file = import_file
  end

  def call!
    ApplicationRecord.transaction do
      # Удаляем «данные строк» этого импорта
      Pass.where(import_file_id: @file.id).delete_all

      # Если позже добавишь FK и захочешь откатывать ещё и эти сущности — раскомментируй:
      # PersonalIdentifierAssignment.where(import_file_id: @file.id).delete_all if col?(:personal_identifier_assignments, :import_file_id)
      # UserDivisionMembership.where(import_file_id: @file.id).delete_all      if col?(:user_division_memberships, :import_file_id)

      # Сам объект импорта тоже уберём
      @file.destroy!
    end
  end

  private

  def col?(table, col)
    ActiveRecord::Base.connection.column_exists?(table, col)
  end

end
