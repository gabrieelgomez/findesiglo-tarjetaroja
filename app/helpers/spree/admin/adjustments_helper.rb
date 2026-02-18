module Spree
  module Admin
    module AdjustmentsHelper
      def display_adjustable(adjustable)
        case adjustable
        when Spree::LineItem
          "#{Spree.t(:line_item)} ##{adjustable.id}"
        when Spree::Shipment
          "#{Spree.t(:shipment)} ##{adjustable.number}"
        when Spree::Order
          "#{Spree.t(:order)} ##{adjustable.number}"
        else
          adjustable.class.name.underscore.humanize
        end
      end
    end
  end
end 