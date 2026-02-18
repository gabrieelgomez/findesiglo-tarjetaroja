module Spree
  module PaymentDecorator
    extend ActiveSupport::Concern

    included do
      has_one_attached :receipt_image, service: Spree.private_storage_service_name

      # validate :require_reference_and_receipt_for_manual_methods
    end

    private

    def require_reference_and_receipt_for_manual_methods
      return unless payment_method.is_a?(Spree::PaymentMethod::Check)
      return unless ["Binance", "Zelle", "Pagomovil", "Dólares Bancamiga"].include?(payment_method.name)

      if referencia.blank?
        errors.add(:referencia, I18n.t('errors.messages.blank'))
      end

      unless receipt_image.attached?
        errors.add(:receipt_image, I18n.t('errors.messages.blank'))
      end
    end
  end
end

Spree::Payment.include Spree::PaymentDecorator 