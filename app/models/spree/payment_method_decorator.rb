module Spree
  module PaymentMethodDecorator
    def self.prepended(base)
      base.has_many :expenses, class_name: 'Expense', foreign_key: 'spree_payment_method_id'
    end
  end
end

Spree::PaymentMethod.prepend(Spree::PaymentMethodDecorator) 