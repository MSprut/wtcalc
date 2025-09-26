# frozen_string_literal: true

class WorktimeQuery

  # scope — Relation на Pass, например:
  #   Pass.where(happened_at: date_from..date_to)
  def initialize(scope, date_from: nil, date_to: nil)
    @scope = scope
    @date_from = date_from || scope.minimum(:happened_at)&.to_date || Date.current
    @date_to   = date_to   || scope.maximum(:happened_at)&.to_date || @date_from
  end

  # [{ user:, hours: Float, days: Integer }]
  def per_user_stats
    by_user_day = compute_user_day_raw_hours # { user_id => { Date => hours_raw } }
    users = User.where(id: by_user_day.keys).index_by(&:id)

    stats = []

    by_user_day.each do |uid, day_hash|
      user = users[uid]
      total = 0.0
      days  = 0

      day_hash.each do |day, raw_hours|
        lb_min = LunchBreak.for(user, day).to_i
        net = [raw_hours - (lb_min / 60.0), 0.0].max
        total += net
        days  += 1 if raw_hours.positive?
      end

      stats << { user: user, hours: total, days: days }
    end

    # Можно отсортировать по ФИО
    stats.sort_by! { |r| [r[:user]&.last_name.to_s, r[:user]&.first_name.to_s] }
    stats
  end

  # [{ date: Date, hours: Float }] — суммарные часы (после вычета обеда) по дням в диапазоне
  def daily_hours_series
    by_user_day = compute_user_day_raw_hours
    out = Hash.new(0.0)

    # суммируем по всем пользователям, вычитая их обед на каждый день
    users = User.where(id: by_user_day.keys).index_by(&:id)
    by_user_day.each do |uid, day_hash|
      u = users[uid]
      day_hash.each do |day, raw|
        lb_min = LunchBreak.for(u, day).to_i
        net = [raw - (lb_min / 60.0), 0.0].max
        out[day] += net
      end
    end

    # гарантируем нули для дней без событий (удобно для графика)
    (@date_from..@date_to).each { |d| out[d] ||= 0.0 }

    out.sort_by { |d, _| d }.map { |d, h| { date: d, hours: h.to_f.round(2) } }
  end

  private

  # Возвращает «сырые» часы по дням и пользователям, без учёта обеда
  # { user_id => { Date => hours_float } }
  def compute_user_day_raw_hours
    rows = @scope
           .where(happened_at: @date_from.beginning_of_day..@date_to.end_of_day)
           .select(:user_id, :happened_at, :direction)
           .order(:user_id, :happened_at)
           .map { |p| [p.user_id, p.happened_at.in_time_zone, p.direction] }

    by_user_day = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    open_in = {} # user_id => Time

    rows.each do |uid, ts, dir|
      case dir
      when 'in'
        # если предыдущий IN не закрыт — перезаписываем началом новой сессии
        open_in[uid] = ts
      when 'out'
        t_in = open_in[uid]
        if t_in && ts > t_in
          allocate_to_days(t_in, ts).each do |day, secs|
            by_user_day[uid][day] += secs / 3600.0
          end
        end
        open_in.delete(uid)
      end
    end

    by_user_day
  end

  # Разбивает интервал [t1, t2) по календарным дням, выдаёт { Date => seconds }
  def allocate_to_days(t1, t2)
    res = {}
    a = t1
    b = t2
    while a.to_date < b.to_date
      day_end = a.end_of_day
      res[a.to_date] = (day_end - a).to_i + 1
      a = day_end + 1.second
    end
    res[a.to_date] = (b - a).to_i if b > a
    res
  end

end
