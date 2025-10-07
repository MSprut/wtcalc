# app/jobs/csv_import_job.rb
class CsvImportJob < ApplicationJob

  queue_as :default

  def perform(import_file_id, raw)
    file = ImportFile.find(import_file_id)
    file.update_columns(status: 'Обработка', progress: 0, updated_at: Time.current)

    importer = CsvImporter.new(StringIO.new(raw), filename: file.filename)
    importer.on_progress do |pct, note|
      file.update_columns(progress: pct, status: note || 'Обработка…', updated_at: Time.current)
    end
    importer.call!

    file.update_columns(status: 'Готово', progress: 100, updated_at: Time.current)
  rescue StandardError => e
    file.update_columns(status: "Ошибка: #{e.message}", updated_at: Time.current)
    raise
  end

end
