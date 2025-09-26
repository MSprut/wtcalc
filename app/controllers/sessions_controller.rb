# frozen_string_literal: true

class SessionsController < ApplicationController

  layout false, only: :new # если хотите чистую страницу без вашего layout — можно убрать

  def new; end

  def create
    login = params[:login].to_s.strip
    pin   = params[:pin].to_s

    user = find_user(login)

    if user&.authenticate_pin(pin)
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: 'Вход выполнен'
    else
      flash.now[:alert] = 'Неверные данные'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: 'Вы вышли'
  end

  private

  # Поддерживает и логин, и персональный номер
  def find_user(login)
    return if login.blank?

    # 1) пробуем как логин (без учёта регистра)
    if (u = User.where('lower(auth_login) = ?', login.downcase).first)
      return u
    end

    # 2) пробуем как персональный номер → ищем активного владельца сейчас
    norm = login.gsub(/[^0-9A-Za-z]/, '').upcase
    return if norm.blank?

    idf = PersonalIdentifier.find_by(normalized_value: norm)
    return unless idf

    pia = PersonalIdentifierAssignment
          .where(personal_identifier_id: idf.id)
          .where('period @> ?', Time.current) # если без tstzrange: ended_at IS NULL
          .first
    pia&.user
  end

end
