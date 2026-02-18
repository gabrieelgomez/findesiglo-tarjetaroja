# frozen_string_literal: true

# Firma mensajes para QZ Tray (SHA1 + RSA, base64).
# Permite que tutarjetaroja.com se conecte a QZ Tray sin popup "Untrusted".
# Lee certificado y clave desde Rails credentials (qz_tray.cert, qz_tray.private_key)
# o desde ENV (QZ_TRAY_CERT_PATH, QZ_TRAY_KEY_PATH) si no hay credentials.
class QzTraySigningService
  class NotConfiguredError < StandardError; end

  def self.certificate_pem
    pem = cert_from_credentials || cert_from_env
    raise NotConfiguredError, "QZ Tray: configura qz_tray en credentials o QZ_TRAY_CERT_PATH" if pem.blank?
    pem.strip
  end

  # Firma el payload que envía QZ Tray (toSign). Devuelve firma en base64.
  # QZ pasa toSign como string raw; hay que firmar exactamente ese string (UTF-8).
  def self.sign(request_data)
    key_pem = key_from_credentials || key_from_env
    raise NotConfiguredError, "QZ Tray: configura qz_tray en credentials o QZ_TRAY_KEY_PATH" if key_pem.blank?

    key = OpenSSL::PKey::RSA.new(key_pem)
    data = request_data.to_s
    # Firmar el string tal cual lo envía QZ (sin decodificar base64)
    signature = key.sign(OpenSSL::Digest.new("SHA1"), data)
    Base64.strict_encode64(signature)
  end

  def self.configured?
    (cert_from_credentials.present? && key_from_credentials.present?) ||
      (ENV["QZ_TRAY_CERT_PATH"].present? && ENV["QZ_TRAY_KEY_PATH"].present? &&
        File.file?(ENV["QZ_TRAY_CERT_PATH"]) && File.file?(ENV["QZ_TRAY_KEY_PATH"]))
  end

  def self.cert_from_credentials
    Rails.application.credentials.dig(:qz_tray, :cert).to_s.presence
  end

  def self.key_from_credentials
    Rails.application.credentials.dig(:qz_tray, :private_key).to_s.presence
  end

  def self.cert_from_env
    path = ENV["QZ_TRAY_CERT_PATH"]
    return nil if path.blank? || !File.file?(path)
    File.read(path)
  end

  def self.key_from_env
    path = ENV["QZ_TRAY_KEY_PATH"]
    return nil if path.blank? || !File.file?(path)
    File.read(path)
  end

end
