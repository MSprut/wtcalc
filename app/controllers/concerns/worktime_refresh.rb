# frozen_string_literal: true

module WorktimeRefresh

  extend ActiveSupport::Concern

  private

  # def load_filters_from_params!
  #   @date_from = (params[:date_from].presence && Date.parse(params[:date_from])) || 14.days.ago.to_date
  #   @date_to = (params[:date_to].presence && Date.parse(params[:date_to])) || Date.current
  #   @filter_user_id = params[:filter_user_id].presence
  # end

  # def rebuild_worktime_frame!
  #   load_filters_from_params!
  #   @stats_page, @series = WorktimeQuery.new(
  #     date_from: @date_from,
  #     date_to: @date_to,
  #     user_id: @filter_user_id # ← фильтр «Все» = nil
  #   ).call
  # end

  def rebuild_worktime_frame!
    @date_from = (params[:date_from].presence && Date.parse(params[:date_from])) || 14.days.ago.to_date
    @date_to   = (params[:date_to].presence   && Date.parse(params[:date_to]))   || Date.current
    @user_id   = params[:filter_user_id].presence

    scope = Pass.where(happened_at: @date_from.beginning_of_day..@date_to.end_of_day)
    scope = scope.where(user_id: @user_id) if @user_id

    query = WorktimeQuery.new(scope, date_from: @date_from, date_to: @date_to)
    @stats = query.per_user_stats
    @pagy, @stats_page = pagy_array(@stats, items: 50)
    @series = query.daily_hours_series
  end

  def render_worktime_frame_turbo!
    render turbo_stream: turbo_stream.update(
      'worktime_frame',
      partial: 'worktime/frame',
      formats: [:html],
      locals: { pagy: @pagy, stats: @stats_page, series: @series,
                date_from: @date_from, date_to: @date_to, user_id: @user_id }
    )
  end

end
