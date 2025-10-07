class WorktimeExportsController < ApplicationController

  require 'csv'

  def index
    date_from = (params[:date_from].presence && Date.parse(params[:date_from])) || 14.days.ago.to_date
    date_to   = (params[:date_to].presence   && Date.parse(params[:date_to]))   || Date.current
    user_id   = params[:filter_user_id].presence

    scope = Pass.where(happened_at: date_from.beginning_of_day..date_to.end_of_day)
    scope = scope.where(user_id: user_id) if user_id

    if params[:mode] == 'matrix'
      dates  = (date_from..date_to).to_a
      matrix = WorktimeQuery.new(scope, date_from: date_from, date_to: date_to).per_user_day_net_hours
      # delta = Σ(h-8)
      matrix.each do |row|
        worked = row[:per_day].values.select { |h| h.to_f > 0 }
        row[:delta] = worked.sum { |h| (h.to_f - 8.0) }.round(2)
      end

      # применяем порядок из URL: order= "12,5,9"
      if params[:order].present?
        order_ids = params[:order].split(',').map(&:to_i)
        by_id     = matrix.index_by { |r| r[:user]&.id }
        ordered   = order_ids.map { |id| by_id.delete(id) }.compact
        rest      = matrix.reject { |r| order_ids.include?(r[:user]&.id) }
        matrix    = ordered + rest
      end

      respond_to do |f|
        f.csv do
          send_data to_csv_matrix(matrix, dates),
                    filename: "Расчет_рабочего_времени_#{l(date_from,
                                                           format: :fname)}_#{l(date_to, format: :fname)}.csv"
        end
        f.xlsx do
          send_data to_xlsx_matrix(matrix, dates), filename: "Расчет_рабочего_времени_#{l(date_from, format: :fname)}_#{l(date_to, format: :fname)}.xlsx",
                                                   type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        end
      end
      return
    end

    # старый «плоский» экспорт (если нужен)
    rows = WorktimeQuery.new(scope, date_from: date_from, date_to: date_to).per_user_stats
    respond_to do |f|
      f.csv  { send_data to_csv(rows), filename: "worktime_#{date_from}_#{date_to}.csv" }
      f.xlsx do
        send_data to_xlsx(rows), filename: "worktime_#{date_from}_#{date_to}.xlsx",
                                 type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      end
    end
  end

  private

  def to_csv_matrix(matrix, dates)
    CSV.generate(col_sep: ';') do |csv|
      csv << ['Сотрудник', *dates.map { |d| I18n.l(d, format: :xshort) }, 'Итого (ч)', 'Δч']
      matrix.each do |r|
        u = r[:user]
        row = []
        row << "#{u.last_name} #{[u.first_name, u.middle_name].compact.map { |x| x.to_s[0] }.join('.')}."
        dates.each do |d|
          h = r[:per_day][d].to_f.round # округлённые
          row << (h > 0 ? h : '')
        end
        row << r[:total_hours].to_f.round(2)
        row << r[:delta].to_f.round(2)
        csv << row
      end
    end
  end

  def to_xlsx_matrix(matrix, dates)
    require 'caxlsx'
    p = Axlsx::Package.new
    p.workbook.add_worksheet(name: 'Matrix') do |s|
      s.add_row ['Сотрудник', *dates.map { |d| I18n.l(d, format: :xshort) }, 'Итого (ч)', 'Δч']
      matrix.each do |r|
        u = r[:user]
        row = []
        row << "#{u.last_name} #{[u.first_name, u.middle_name].compact.map { |x| x.to_s[0] }.join('.')}."
        dates.each do |d|
          h = r[:per_day][d].to_f.round # округлённые
          row << (h > 0 ? h : '')
        end
        row << r[:total_hours].to_f.round(2)
        row << r[:delta].to_f.round(2)
        s.add_row row
      end
    end
    p.to_stream.read
  end

  # старые to_csv / to_xlsx оставь как были

  def to_csv(rows)
    CSV.generate(col_sep: ';') do |csv|
      csv << %w[Сотрудник Подразделение Дней Часы Переработка Недоработка]
      rows.each do |r|
        u = r[:user]
        days = r[:days].to_i
        hours = r[:hours].to_f.round(2)
        base = (days * 8.0).round(2)
        delta = (hours - base).round(2)
        over =  delta.positive? ?  delta : 0.0
        under = delta.negative? ? -delta : 0.0
        csv << ["#{u.last_name} #{u.first_name}", u.current_division&.name, days, hours, over, under]
      end
    end
  end

  def to_xlsx(rows)
    require 'caxlsx' # добавь gem 'caxlsx' в Gemfile, если нужен xlsx
    p = Axlsx::Package.new
    p.workbook.add_worksheet(name: 'Worktime') do |s|
      s.add_row %w[Сотрудник Подразделение Дней Часы Переработка Недоработка]
      rows.each do |r|
        u = r[:user]
        days = r[:days].to_i
        hours = r[:hours].to_f.round(2)
        base = (days * 8.0).round(2)
        delta = (hours - base).round(2)
        over =  delta.positive? ?  delta : 0.0
        under = delta.negative? ? -delta : 0.0
        s.add_row ["#{u.last_name} #{u.first_name}", u.current_division&.name, days, hours, over, under]
      end
    end
    p.to_stream.read
  end

end

# # frozen_string_literal: true

# class WorktimeExportsController < ApplicationController

#   def index
#     date_from = (params[:date_from].presence && Date.parse(params[:date_from])) || 14.days.ago.to_date
#     date_to   = (params[:date_to].presence   && Date.parse(params[:date_to]))   || Date.current
#     user_id   = params[:filter_user_id].presence

#     scope = Pass.where(happened_at: date_from.beginning_of_day..date_to.end_of_day)
#     scope = scope.where(user_id: user_id) if user_id

#     rows = WorktimeQuery.new(scope, date_from: date_from, date_to: date_to).per_user_stats

#     respond_to do |f|
#       f.csv  { send_data to_csv(rows), filename: "worktime_#{date_from}_#{date_to}.csv" }
#       f.xlsx do
#         send_data to_xlsx(rows), filename: "worktime_#{date_from}_#{date_to}.xlsx",
#                                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
#       end
#     end
#   end

#   private

#   def to_csv(rows)
#     CSV.generate(col_sep: ';') do |csv|
#       csv << %w[Сотрудник Подразделение Дней Часы Переработка Недоработка]
#       rows.each do |r|
#         u = r[:user]
#         days = r[:days].to_i
#         hours = r[:hours].to_f.round(2)
#         base = (days * 8.0).round(2)
#         delta = (hours - base).round(2)
#         over =  delta.positive? ?  delta : 0.0
#         under = delta.negative? ? -delta : 0.0
#         csv << ["#{u.last_name} #{u.first_name}", u.current_division&.name, days, hours, over, under]
#       end
#     end
#   end

#   def to_xlsx(rows)
#     require 'caxlsx' # добавь gem 'caxlsx' в Gemfile, если нужен xlsx
#     p = Axlsx::Package.new
#     p.workbook.add_worksheet(name: 'Worktime') do |s|
#       s.add_row %w[Сотрудник Подразделение Дней Часы Переработка Недоработка]
#       rows.each do |r|
#         u = r[:user]
#         days = r[:days].to_i
#         hours = r[:hours].to_f.round(2)
#         base = (days * 8.0).round(2)
#         delta = (hours - base).round(2)
#         over =  delta.positive? ?  delta : 0.0
#         under = delta.negative? ? -delta : 0.0
#         s.add_row ["#{u.last_name} #{u.first_name}", u.current_division&.name, days, hours, over, under]
#       end
#     end
#     p.to_stream.read
#   end

# end
