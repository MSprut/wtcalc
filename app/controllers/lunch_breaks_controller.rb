# frozen_string_literal: true

class LunchBreaksController < ApplicationController

  include WorktimeRefresh

  def global
    minutes = params.require(:lunch_break).permit(:minutes)[:minutes].to_i
    LunchBreak.set_global!(minutes)

    rebuild_worktime_frame!
    streams = []
    streams << turbo_stream.replace(
      'worktime_summary',
      partial: 'worktime/summary_cards',
      formats: [:html],
      locals: { stats: @stats_page }
    )
    streams << turbo_stream.replace(
      'worktime_chart',
      partial: 'worktime/chart',
      formats: [:html],
      locals: { series: @series, date_from: @date_from, date_to: @date_to }
    )
    # таблицу целиком не трогаем — строки сами показывают часы после пересчёта

    respond_to do |f|
      f.turbo_stream { render turbo_stream: streams } # ← только стримы
      f.html         do
        redirect_to worktime_path(date_from: @date_from, date_to: @date_to, user_id: @user_id),
                    notice: 'Глобальный обед обновлён'
      end
      f.any { render turbo_stream: streams } # на случай Accept: */*
    end
    # respond_to do |f|
    #   f.turbo_stream { render_worktime_frame_turbo! }
    #   f.html do
    #     redirect_to worktime_path(date_from: @date_from, date_to: @date_to, user_id: @user_id),
    #                 notice: 'Глобальный обед обновлён'
    #   end
    # end
    # respond_to do |f|
    #   f.turbo_stream do
    #     render turbo_stream: turbo_stream.update('lb_flash', partial: 'shared/flash',
    #                                                          locals: { notice: "Глобальный обед: #{minutes} мин" })
    #   end
    #   f.html { redirect_back fallback_location: root_path, notice: "Глобальный обед обновлён: #{minutes} мин" }
    # end
  end

end
