# frozen_string_literal: true

class HealthController < ApplicationController

  def index
    db_ok = true
    db_error = nil

    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
    rescue StandardError => e
      db_ok = false
      db_error = e.message
    end

    @status = db_ok ? 'ok' : 'error'
    @db_status = db_ok
    @db_error = db_error
    render :index
  end

end
