module Spree
  module Admin
    class BcvsController < Spree::Admin::BaseController
      before_action :load_bcv

      def edit
      end

      def update
        if @bcv.update(bcv_params)
          redirect_to spree.edit_admin_bcv_path(@bcv), notice: 'BCV actualizado exitosamente'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def load_bcv
        @bcv = Bcv.last || Bcv.create(value: 0, value_whatsapp: 0)
      end

      def bcv_params
        params.require(:bcv).permit(:value, :value_whatsapp)
      end
    end
  end
end

