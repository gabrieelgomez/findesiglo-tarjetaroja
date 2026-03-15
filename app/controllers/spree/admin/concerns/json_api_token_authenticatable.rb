# frozen_string_literal: true

module Spree
  module Admin
    module Concerns
      # Permite acceso JSON a endpoints de reportes con:
      # - Usuario admin logueado (sesión), o
      # - Token válido (header Authorization: Bearer TOKEN o param token) para consumo API entre apps.
      # Token configurado en Rails credentials como token_api_json.
      module JsonApiTokenAuthenticatable
        extend ActiveSupport::Concern

        included do
          # Sobrescribir authorize_admin del BaseController para permitir token en JSON
          define_method :authorize_admin do
            return if request.format.json? && valid_json_api_token?

            super()
          end

          # Para JSON sin sesión/token válido devolver 401 en lugar de redirect
          define_method :redirect_unauthorized_access do
            if request.format.json?
              render json: { error: 'Unauthorized' }, status: :unauthorized
            else
              super()
            end
          end
        end

        private

        def valid_json_api_token?
          token = api_token_from_request
          return false if token.blank?

          expected = Rails.application.credentials.dig(:token_api_json).to_s.presence
          return false if expected.blank?

          ActiveSupport::SecurityUtils.secure_compare(token, expected)
        end

        def api_token_from_request
          request.headers['Authorization']&.sub(/\ABearer\s+/i, '')&.strip ||
            params[:token].to_s.strip.presence
        end
      end
    end
  end
end
