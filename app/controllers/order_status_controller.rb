# Controlador público para consultar el estado de un pedido por número.
# URL: /estado-pedido?order=R923227399
# No requiere autenticación.
class OrderStatusController < ApplicationController
  before_action :load_order, only: [:show]

  def show
    # Vista maneja: sin parámetro (formulario), orden no encontrada, orden encontrada
  end

  private

  def load_order
    return unless params[:order].present?

    number = params[:order].to_s.strip
    @order = Spree::Order.find_by(number: number)
  end
end
