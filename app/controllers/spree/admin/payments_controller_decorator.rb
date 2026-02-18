module Spree
  module Admin
    module PaymentsControllerDecorator
      private

      def permitted_payment_attributes
        [:amount, :payment_method_id, :payment_method, :traspaso, :referencia, :monto_bolivares] + [
          source_attributes: permitted_source_attributes
        ]
      end
    end
  end
end

::Spree::Admin::PaymentsController.prepend Spree::Admin::PaymentsControllerDecorator if ::Spree::Admin::PaymentsController.included_modules.exclude?(Spree::Admin::PaymentsControllerDecorator) 