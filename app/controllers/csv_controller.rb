# frozen_string_literal: true

class CsvController < ApplicationController

  def index
    @pagy, @passes = pagy(recent_passes)
  end

  def create
    return respond_with_error!('Выберите CSV-файл') if params[:file].blank?

    upload  = params[:file]
    result  = CsvImporter.new(upload, filename: upload.original_filename).call!
    msg = "Импорт: строк=#{result[:rows]}, компаний+#{result[:companies_new]}, подразделений+#{result[:divisions_new]}, пользователей+#{result[:users_new]}, проходов=#{result[:passes]}"
    flash.now[:notice] = msg

    @pagy, @passes = pagy(recent_passes)

    respond_to do |f|
      # f.turbo_stream { render turbo_stream: turbo_stream.update('csv_flash', partial: 'shared/flash') }
      f.turbo_stream do
        render turbo_stream: [
          turbo_stream.update('csv_flash', partial: 'shared/flash'),
          turbo_stream.replace('csv_table', partial: 'csv/summary_table', locals: { passes: @passes })
        ]
      end
      f.html { redirect_to root_path, notice: msg }
    end
  rescue StandardError => e
    Rails.logger.error(e.full_message)
    respond_with_error!("Ошибка импорта: #{e.message}")
  end

  # def create
  #   return respond_with_error!('Выберите CSV-файл') if params[:file].blank?

  #   upload = params[:file] # ActionDispatch::Http::UploadedFile

  #   importer = CsvImporter.new(upload, filename: upload.original_filename)
  #   importer.call!

  #   flash.now[:notice] = "Импорт завершён: #{upload.original_filename}"
  #   respond_ok
  # rescue CSV::MalformedCSVError => e
  #   respond_with_error!("Некорректный CSV: #{e.message}")
  # rescue StandardError => e
  #   Rails.logger.error("CSV import error: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
  #   respond_with_error!("Ошибка импорта: #{e.full_message}")
  # end

  private

  def recent_passes
    Pass.order(user_id: :asc) # order(happened_at: :desc).limit(300)
        .includes(user: [:user_division_memberships, { personal_identifier_assignments: :personal_identifier }])
  end

  def respond_ok
    respond_to do |f|
      f.turbo_stream # { render turbo_stream: turbo_stream.update('csv_flash', partial: 'shared/flash') }
      f.html { redirect_to root_path, notice: flash.now[:notice] }
    end
  end

  def respond_with_error!(msg)
    flash.now[:alert] = msg
    respond_to do |f|
      f.turbo_stream do
        render turbo_stream: turbo_stream.update('csv_flash', partial: 'shared/flash'), status: :unprocessable_entity
      end
      f.html { redirect_to root_path, alert: msg }
    end
  end

  # def respond_with_error!(msg)
  #   flash.now[:alert] = msg
  #   respond_to do |f|
  #     f.turbo_stream do
  #       render turbo_stream: turbo_stream.update('csv_flash', partial: 'shared/flash'), status: :unprocessable_entity
  #     end
  #     f.html { redirect_to root_path, alert: msg }
  #   end
  # end

  # require 'csv'

  # before_action :ensure_file!, only: :create

  # def index; end

  # def create
  #   @headers, @rows = extract_headers_and_rows(params[:file])
  #   respond
  # end

  # private

  # def extract_headers_and_rows(file)
  #   table    = read_table(file)
  #   keep_idx = kept_indices(table.headers)
  #   [
  #     map_headers(table.headers, keep_idx),
  #     map_rows(table, keep_idx)
  #   ]
  # end

  # # читаем CSV, режем BOM, авто-детект разделителя по первой строке
  # def read_table(file)
  #   CSV.read(
  #     file.path,
  #     headers: true,
  #     encoding: 'bom|utf-8',
  #     col_sep: sniff_col_sep(file.path)
  #   )
  # end

  # def sniff_col_sep(path)
  #   first = File.open(path, 'r:bom|utf-8', &:gets) || ''
  #   first.count(';') > first.count(',') ? ';' : ','
  # end

  # def kept_indices(headers)
  #   normalized = headers.map { |h| h.to_s.strip }
  #   normalized.each_index.select { |i| normalized[i].present? }
  # end

  # def map_headers(headers, idxs)
  #   idxs.map { |i| headers[i].to_s.strip }
  # end

  # def map_rows(table, idxs)
  #   table.map { |row| idxs.map { |i| row[i] } }
  # end

  # def respond
  #   respond_to do |format|
  #     format.turbo_stream
  #     format.html { render :index }
  #   end
  # end

  # def ensure_file!
  #   @headers = []
  #   @rows = []
  #   return if request.post? && params[:file].present?

  #   respond and return
  # end

end

# class CsvController < ApplicationController
#   require 'csv'

#   def index
#   end

#   def create
#     # @rows = []
#     # if request.post? && params[:file].present?
#     #   # читаем загруженный CSV; 'bom|utf-8' срежет BOM, если он есть
#     #   @rows = CSV.read(params[:file].path, encoding: "bom|utf-8", headers: true)
#     #   # если нужен другой разделитель: CSV.read(..., col_sep: ";")
#     #   # если нужны заголовки: CSV.read(..., headers: true).map(&:fields)
#     # end

#     # @headers = []
#     # @rows = []
#     # if request.post? && params[:file].present?
#     #   data = params[:file].read
#     #   data.delete_prefix!("\xEF\xBB\xBF".b) # срезаем BOM, если есть
#     #   # грубая автонастройка разделителя: ; или ,
#     #   col_sep = data.include?(";\n") || data.include?(";\r\n") ? ";" : ","
#     #   parsed  = CSV.parse(data, headers: true, col_sep: col_sep)
#     #   @headers = parsed.headers
#     #   @rows    = parsed.map { |r| r.fields }
#     # end

#     @headers = []
#     @rows = []
#     return unless request.post? && params[:file].present?

#     file = params[:file]

#     # лёгкий сниффер разделителя по первой строке
#     first_line = File.open(file.path, 'r:bom|utf-8', &:gets) || ''
#     col_sep = first_line.count(';') > first_line.count(',') ? ';' : ','

#     table = CSV.read(file.path, headers: true, encoding: 'bom|utf-8', col_sep: col_sep)

#     normalized = table.headers.map { |h| h.to_s.strip }

#     # 2) берём только индексы с НЕпустым заголовком
#     keep_idx = normalized.each_index.select { |i| !normalized[i].empty? }

#     @headers = keep_idx.map { |i| normalized[i] } # table.headers
#     @rows    = table.map { |row| keep_idx.map { |i| row[i] } } # table.map { |r| r.fields }

#     # flash.now[:notice] = "Загружено строк: #{@rows.size}"
#     # Rails.logger.info "CSV headers=#{normalized.inspect} keep_idx=#{keep_idx.inspect} rows=#{@rows.size}"
#     # Rails.logger.info "CSV headers=#{@headers.inspect} rows=#{@rows.inspect} rows=#{@rows.size}"

#     respond
#   end

#   # def normalized headers
#   #   headers.map { |h| h.to_s.strip }
#   # end

#   # def kept_idx normalized_headers
#   #   # 2) берём только индексы с НЕпустым заголовком
#   #   normalized_headers.each_index.select { |i| !normalized_headers[i].empty? }
#   # end
#   def respond
#     respond_to do |format|
#       format.turbo_stream
#       format.html { render :index }
#     end
#   end
# end
