module ApplicationHelper
  def translate_variant_options(options_text)
    return options_text if options_text.blank?
    
    # Traducir términos comunes de opciones de variantes
    translated = options_text.dup
    
    # Traducir "Size:" a "Talla:"
    translated.gsub!(/Size:/, I18n.t(:size) + ':')
    
    # Traducir "dorsales:" a "Dorsales:"
    translated.gsub!(/dorsales:/, I18n.t(:dorsales) + ':')
    
    translated
  end

  def order_state_badge_class(state)
    case state.to_s
    when 'complete'
      'success'
    when 'shipped'
      'info'
    when 'delivered'
      'primary'
    when 'canceled'
      'danger'
    when 'returned'
      'warning'
    else
      'secondary'
    end
  end
end
