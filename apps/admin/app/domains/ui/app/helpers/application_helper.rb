module ApplicationHelper
  def truncate_fiat(value, currency_code = nil)
    return "" if value.nil?

    decimal = BigDecimal(value.to_s)
    return decimal.to_s("F") if currency_code.present? && !FCS::Currency.fiat?(currency_code)

    formatted = decimal.truncate(2).to_s("F")
    formatted.sub(/\.0+\z/, "").sub(/\.(\d*[1-9])0+\z/, '.\\1')
  rescue ArgumentError
    value.to_s
  end
end
