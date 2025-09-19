class CsvController < ApplicationController
  require "csv"

  def index
  end

  def create
    # @rows = []
    # if request.post? && params[:file].present?
    #   # читаем загруженный CSV; 'bom|utf-8' срежет BOM, если он есть
    #   @rows = CSV.read(params[:file].path, encoding: "bom|utf-8", headers: true)
    #   # если нужен другой разделитель: CSV.read(..., col_sep: ";")
    #   # если нужны заголовки: CSV.read(..., headers: true).map(&:fields)
    # end


    # @headers = []
    # @rows = []
    # if request.post? && params[:file].present?
    #   data = params[:file].read
    #   data.delete_prefix!("\xEF\xBB\xBF".b) # срезаем BOM, если есть
    #   # грубая автонастройка разделителя: ; или ,
    #   col_sep = data.include?(";\n") || data.include?(";\r\n") ? ";" : ","
    #   parsed  = CSV.parse(data, headers: true, col_sep: col_sep)
    #   @headers = parsed.headers
    #   @rows    = parsed.map { |r| r.fields }
    # end


    @headers = []
    @rows = []
    return unless request.post? && params[:file].present?

    file = params[:file]

    # лёгкий сниффер разделителя по первой строке
    first_line = File.open(file.path, "r:bom|utf-8", &:gets) || ""
    col_sep = first_line.count(";") > first_line.count(",") ? ";" : ","

    table = CSV.read(file.path, headers: true, encoding: "bom|utf-8", col_sep: col_sep)

    normalized = table.headers.map { |h| h.to_s.strip }

    # 2) берём только индексы с НЕпустым заголовком
    keep_idx = normalized.each_index.select { |i| !normalized[i].empty? }

    @headers = keep_idx.map { |i| normalized[i] } # table.headers
    @rows    = table.map { |row| keep_idx.map { |i| row[i] } } # table.map { |r| r.fields }

    # flash.now[:notice] = "Загружено строк: #{@rows.size}"
    # Rails.logger.info "CSV headers=#{normalized.inspect} keep_idx=#{keep_idx.inspect} rows=#{@rows.size}"
    # Rails.logger.info "CSV headers=#{@headers.inspect} rows=#{@rows.inspect} rows=#{@rows.size}"

    respond
  end

  # def normalized headers
  #   headers.map { |h| h.to_s.strip }
  # end

  # def kept_idx normalized_headers
  #   # 2) берём только индексы с НЕпустым заголовком
  #   normalized_headers.each_index.select { |i| !normalized_headers[i].empty? }
  # end
  def respond
    respond_to do |format|
      format.turbo_stream # do
      # render turbo_stream: [
      # turbo_stream.update("csv_flash",  partial: "shared/flash"),
      # turbo_stream.update("csv_table",  partial: "csv/table", locals: { headers: @headers, rows: @rows })
      # ]
      # end
      format.html { render :index } # фолбэк
    end
  end
end
