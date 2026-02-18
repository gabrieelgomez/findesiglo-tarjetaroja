module Spree
  module Admin
    module AddressImagesHelper
      def address_image_path(address)
        spree.admin_address_image_path(address)
      end
    end
  end
end 