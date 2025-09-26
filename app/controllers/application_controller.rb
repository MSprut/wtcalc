# frozen_string_literal: true

class ApplicationController < ActionController::Base

  include Pagy::Backend
  include ActionView::RecordIdentifier # for working the dom_id in UserLunchBreaksController#rerender_days
  include ActionController::MimeResponds

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern
  helper_method :current_user

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id])
  end

  def require_login!
    redirect_to login_path, alert: 'Требуется вход' unless current_user
  end

end
