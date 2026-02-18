# frozen_string_literal: true

module Spree
  module Admin
    class VariantChangeLogsController < Spree::Admin::BaseController
      before_action :authorize_variant_change_logs

      def model_class
        Spree::Variant
      end

      def index
        @change_logs = VariantChangeLog
          .where(field_name: %w[count_on_hand backorderable])
          .includes(:admin_user, :product, :variant)
          .recent
          .page(params[:page])
          .per(params[:per_page].presence || 25)

        @change_logs = @change_logs.where(admin_user_id: params[:user_id]) if params[:user_id].present?
        @change_logs = @change_logs.where(product_id: params[:product_id]) if params[:product_id].present?
        @change_logs = @change_logs.where(variant_id: params[:variant_id]) if params[:variant_id].present?
        @change_logs = @change_logs.where(source: params[:source]) if params[:source].present?
        if params[:since].present?
          since = Time.zone.parse(params[:since]) rescue nil
          @change_logs = @change_logs.where('variant_change_logs.created_at >= ?', since) if since
        end
      end

      private

      def authorize_variant_change_logs
        authorize! :manage, Spree::Variant
      end
    end
  end
end
