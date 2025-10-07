# frozen_string_literal: true

module ApplicationHelper

  include Pagy::Frontend
  include WorktimeHelper

  def nav_item(name, path, starts_with: nil, **link_opts)
    active = current_page?(path) || Array(starts_with).any? { |p| request.path.start_with?(p) }
    content_tag(:li, class: 'nav-item') do
      link_to name, path, { class: "nav-link#{' active' if active}",
                            'aria-current': (active ? 'page' : nil) }.merge(link_opts)
    end
  end

  # элемент в dropdown (активный подсветится)
  def nav_dropdown_item(name, path, **opts)
    link_to name, path, { class: "dropdown-item#{' active' if current_page?(path)}" }.merge(opts)
  end

  # активность для группы путей (подсветить сам dropdown)
  def any_active?(paths)
    Array(paths).any? { |p| current_page?(p) || request.path.start_with?(p) }
  end

  def tz(time, format: :short)
    return '—' unless time

    l(time.in_time_zone(Time.zone), format: format)
  end

  # Маленький прогресс-бар Bootstrap
  def progress_bar(pct)
    content_tag(:div, class: 'progress', style: 'height:8px;') do
      content_tag(:div, nil,
                  class: 'progress-bar',
                  role: 'progressbar',
                  style: "width: #{pct.to_i.clamp(0, 100)}%;",
                  aria: { valuemin: 0, valuemax: 100, valuenow: pct.to_i })
    end
  end

  def status_badge(text)
    s = text.to_s
    klass =
      if s.start_with?('Ошибка', 'Error') then 'bg-danger'
      elsif %w[Готово Done].include?(s) then 'bg-success'
      elsif ['В очереди', 'Ожидание'].include?(s) then 'bg-secondary'
      else
        'bg-warning text-dark'
      end
    content_tag(:span, s, class: "badge #{klass}")
  end

end
