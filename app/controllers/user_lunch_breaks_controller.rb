# frozen_string_literal: true

class UserLunchBreaksController < ApplicationController

  include WorktimeRefresh

  before_action :set_user

  # upsert per-day
  def create
    on_date = Date.parse(params[:on_date])
    minutes = params.require(:lunch_break).permit(:minutes)[:minutes].to_i
    lb = LunchBreak.find_or_initialize_by(user: @user, on_date: on_date)
    lb.minutes = minutes
    lb.save!

    rebuild_worktime_frame!
    render_streams_or_redirect

    # render_frame_or_redirect

    # respond_to do |f|
    #   f.turbo_stream { render_worktime_frame_turbo! }
    #   f.html do
    #     redirect_to worktime_path(date_from: @date_from, date_to: @date_to, user_id: @user_id), notice: 'Сохранено'
    #   end
    # end
    # respond_for_lunch_change
    # rerender_days(on_date)
  end

  def update
    create
  end

  # опционально: установить личный дефолт (без даты)
  def default
    minutes = params.require(:lunch_break).permit(:minutes)[:minutes].to_i
    lb = LunchBreak.find_or_initialize_by(user: @user, on_date: nil)
    lb.minutes = minutes
    lb.save!

    rebuild_worktime_frame!
    render_streams_or_redirect

    # render_frame_or_redirect

    # respond_to do |f|
    #   f.turbo_stream { render_worktime_frame_turbo! }
    #   f.html do
    #     redirect_to worktime_path(date_from: @date_from, date_to: @date_to, user_id: @user_id), notice: 'Сохранено'
    #   end
    # end
    # respond_for_lunch_change
    # rerender_days
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def render_streams_or_redirect
    row = @stats_page.find { |r| r[:user]&.id == @user.id }

    streams = []
    # 1) карточки + график
    streams << turbo_stream.replace(
      'worktime_summary',
      partial: 'worktime/summary_cards', formats: [:html],
      locals: { stats: @stats_page }
    )
    streams << turbo_stream.replace(
      'worktime_chart',
      partial: 'worktime/chart', formats: [:html],
      locals: { series: @series, date_from: @date_from, date_to: @date_to }
    )

    if row
      # 2) обновляем только числа в строке
      streams << turbo_stream.update("user_#{@user.id}_hours",
                                     ApplicationController.render(inline: "<%= number_with_precision(#{row[:hours].to_f}, precision: 2) %>"))
      streams << turbo_stream.update("user_#{@user.id}_days",
                                     ApplicationController.render(inline: "<%= #{row[:days].to_i} %>"))

      # 3) обновляем содержимое блока «Дни»
      streams << turbo_stream.update(
        helpers.dom_id(@user, :lunch_days),
        partial: 'lunch_breaks/user_days', formats: [:html],
        locals: { user: @user, date_from: @date_from, date_to: @date_to }
      )
    end

    respond_to do |f|
      f.turbo_stream { render turbo_stream: streams }
      f.html         do
        redirect_to worktime_path(date_from: @date_from, date_to: @date_to, user_id: @user_id), notice: 'Сохранено'
      end
      f.any { render turbo_stream: streams }
    end
  end

  # def render_frame_or_redirect
  #   if turbo_frame_request?
  #     render partial: 'worktime/frame',
  #            formats: [:html],
  #            locals: { pagy: @pagy, stats: @stats_page, series: @series,
  #                      date_from: @date_from, date_to: @date_to, user_id: @user_id }
  #   else
  #     redirect_to worktime_path(date_from: @date_from, date_to: @date_to, user_id: @user_id),
  #                 notice: 'Сохранено'
  #   end
  # end

  # def respond_for_lunch_change
  #   # если пришёл Turbo — обновляем весь рабочий фрейм (чтобы часы/график пересчитались)
  #   if request.format.turbo_stream?
  #     render_worktime_frame_turbo!
  #   else
  #     # HTML фолбэк
  #     redirect_to worktime_path(
  #       date_from: @date_from, date_to: @date_to, user_id: params[:user_id].presence
  #     ), notice: 'Сохранено'
  #   end
  # end

  # def rerender_days(anchor_date = nil)
  #   @date_from = (params[:date_from].presence && Date.parse(params[:date_from])) || 14.days.ago.to_date
  #   @date_to   = (params[:date_to].presence   && Date.parse(params[:date_to]))   || Date.current

  #   respond_to do |f|
  #     f.turbo_stream do
  #       render turbo_stream: turbo_stream.replace(
  #         dom_id(@user, :lunch_days),
  #         partial: 'lunch_breaks/user_days',
  #         locals: { user: @user, date_from: @date_from, date_to: @date_to }
  #       )
  #     end
  #     f.html { redirect_back fallback_location: root_path }
  #   end
  # end

end
