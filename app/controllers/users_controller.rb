# frozen_string_literal: true

class UsersController < ApplicationController

  def index
  end

  def update_lunch_break
    user = User.find(params[:id])
    minutes = params.require(:user).permit(:lunch_break_minutes)[:lunch_break_minutes].to_i
    user.update!(lunch_break_minutes: minutes)
    respond_to do |f|
      f.turbo_stream do
        render turbo_stream: turbo_stream.replace(dom_id(user, :row), partial: 'worktime/user_row',
                                                                      locals: { row: WorktimeRowPresenter.new(user) })
      end
      f.html { redirect_back fallback_location: root_path, notice: 'Сохранено' }
    end
  end

end
