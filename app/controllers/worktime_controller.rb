# frozen_string_literal: true

class WorktimeController < ApplicationController

  include Pagy::Backend

  def show
    @date_from = (params[:date_from].presence && Date.parse(params[:date_from])) || 14.days.ago.to_date
    @date_to   = (params[:date_to].presence   && Date.parse(params[:date_to]))   || Date.current
    @user_id   = params[:filter_user_id].presence

    scope = Pass.where(happened_at: @date_from.beginning_of_day..@date_to.end_of_day)
    scope = scope.where(user_id: @user_id) if @user_id

    @users_all = User.order(:last_name, :first_name)
    # агрегат по пользователям (пример: hours_with_break — часы минус обед)
    # подставь свою агрегацию
    query = WorktimeQuery.new(scope, date_from: @date_from, date_to: @date_to)
    @stats = query.per_user_stats
    @pagy, @stats_page = pagy_array(@stats, items: 50)
    @series = query.daily_hours_series

    respond_to do |f|
      f.html
      f.turbo_stream { render partial: 'worktime/frame', formats: [:html], locals: frame_locals }
    end
  end

  # def days
  #   @user      = User.find(params[:user_id])
  #   @date_from = Date.parse(params[:date_from])
  #   @date_to   = Date.parse(params[:date_to])

  #   preload_lunch_breaks([@user.id], @date_from, @date_to)
  #   render partial: 'lunch_breaks/user_days', locals: { user: @user, date_from: @date_from, date_to: @date_to }
  # end

  def days
    @user      = User.find(params[:user_id])
    @date_from = Date.parse(params[:date_from])
    @date_to   = Date.parse(params[:date_to])

    # Предзагрузим всё, что нужно для быстрого рендера partial
    preload_lunch_breaks([@user.id], @date_from, @date_to) if respond_to?(:preload_lunch_breaks, true)

    # render partial: 'lunch_breaks/user_days',
    #  locals: { user: @user, date_from: @date_from, date_to: @date_to }
    render :days, layout: false
  end

  private

  def preload_lunch_breaks(user_ids, from, to)
    @lb_map            = {}
    @lb_user_default   = {}
    @lb_global_default = nil

    # Все дневные значения одним pluck
    lbs = LunchBreak.where(user_id: user_ids, on_date: from..to)
                    .pluck(:user_id, :on_date, :minutes)
    @lb_map = lbs.each_with_object({}) { |(uid, d, m), h| h[[uid, d]] = m }

    # Все пользовательские дефолты (on_date: nil) — одним pluck
    @lb_user_default = LunchBreak.where(user_id: user_ids, on_date: nil)
                                 .pluck(:user_id, :minutes).to_h

    # Глобальный дефолт (user_id: nil, on_date: nil) — один запрос
    @lb_global_default = LunchBreak.find_by(user_id: nil, on_date: nil)&.minutes
  end

  # def preload_lunch_breaks(user_ids, from, to)
  #   lbs = LunchBreak.for_range(user_ids, from, to).pluck(:user_id, :on_date, :minutes)
  #   @lb_map = lbs.each_with_object({}) { |(uid, d, m), h| h[[uid, d]] = m }

  #   @lb_user_default = LunchBreak.user_defaults(user_ids).pluck(:user_id, :minutes).to_h
  #   @lb_global_default = LunchBreak.global_default
  # end

  def frame_locals
    { pagy: @pagy, stats: @stats_page, series: @series, date_from: @date_from, date_to: @date_to, user_id: @user_id }
  end

end
