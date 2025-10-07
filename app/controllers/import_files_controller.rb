# frozen_string_literal: true

class ImportFilesController < ApplicationController

  def index
    @import_files =
      ImportFile
      .left_joins(:passes)
      .select('import_files.*, COUNT(passes.id) AS passes_count')
      .group('import_files.id')
      .order(created_at: :desc)
    # @import_files = ImportFile.order(created_at: :desc)
  end

  def show
    file = ImportFile.find(params[:id])
    respond_to do |f|
      f.json { render json: { progress: file.progress, status: file.status, filename: file.filename } }
      f.html { redirect_to csv_index_path }
    end
  end

  def destroy_last
    file = ImportFile.order(created_at: :desc).first
    return redirect_back fallback_location: csv_index_path, alert: 'Нет импортов' unless file

    ImportFileDestroyer.new(file).call!
    redirect_to csv_index_path, notice: "Импорт «#{file.filename}» удалён"
  end

  def destroy
    file = ImportFile.find(params[:id])
    ImportFileDestroyer.new(file).call!
    redirect_to import_files_path, notice: "Импорт «#{file.filename}» удалён"
  end

end
