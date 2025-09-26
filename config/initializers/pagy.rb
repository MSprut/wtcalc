# frozen_string_literal: true

require 'pagy/extras/bootstrap'  # кнопки под Bootstrap
require 'pagy/extras/i18n'       # локализация
require 'pagy/extras/array'      # ← это нужно для pagy_array(...)

# необязательно: trim убирает ?page=1
# require "pagy/extras/trim"
Pagy::DEFAULT[:items] = 50
