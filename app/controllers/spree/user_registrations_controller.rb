module Spree
  class UserRegistrationsController < ::Devise::RegistrationsController
    include Spree::Storefront::DeviseConcern

    protected

    def translation_scope
      'devise.user_registrations'
    end

    private

    def title
      Spree.t(:sign_up)
    end

    def sign_up_params
      params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name, :phone, :identifier)
    end
  end
end
