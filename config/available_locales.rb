# coding: utf-8
module Sharetribe

  # Format: [name, identifier, language, region, fallback identifier]
  #
  # language format: ISO 639-1, two letters, lowercase
  # region format: ISO 3166, two letters, uppercase
  # fallbacks: should not include US English, which is a last default fallback for each language

  SUPPORTED_LOCALES = [
    {ident: "da-DK", name: "Dansk", language: "da", region: "DK", fallback: nil}, # Danish (Denmark)
    {ident: "de", name: "Deutsch", language: "de", region: "DE", fallback: nil}, # German (Germany)
    {ident: "el", name: "Ελληνικά", language: "el", region: "GR", fallback: nil}, # Greek (Greece)
    {ident: "en", name: "English", language: "en", region: "US", fallback: nil}, # English (United States)
    {ident: "es-ES", name: "Español", language: "es", region: "ES", fallback: nil}, # Spanish (Spain)
    {ident: "fi", name: "Suomi", language: "fi", region: "FI", fallback: nil}, # Finnish (Finland)
    {ident: "fr", name: "Français", language: "fr", region: "FR", fallback: nil}, # French (France)
    {ident: "it", name: "Italiano", language: "it", region: "IT", fallback: nil}, # Italian (Italy)
    {ident: "ja", name: "日本語", language: "ja", region: "JP", fallback: nil}, # Japanese (Japan)
    {ident: "nb", name: "Norsk", language: "nb", region: "NO", fallback: nil}, # Norwegian Bokmål (Norway)
    {ident: "nl", name: "Nederlands", language: "nl", region: "NL", fallback: nil}, # Dutch (Netherlands)
    {ident: "pt-BR", name: "Português do Brasil", language: "pt", region: "BR", fallback: nil}, # Portuguese (Brazil)
    {ident: "ru", name: "Pусский", language: "ru", region: "RU", fallback: nil}, # Russian (Russia)
    {ident: "sv", name: "Svenska", language: "sv", region: "SE", fallback: nil}, # Swedish (Sweden)
    {ident: "tr-TR", name: "Turkish", language: "tr", region: "TR", fallback: nil}, # Turkish (Turkey)
    {ident: "zh", name: "中文", language: "zh", region: "CN", fallback: nil}, # Chinese (China)
  ]

  UNSUPPORTED_LOCALES = [
    {ident: "ca", name: "Catalan", language: "ca", region: "ES", fallback: nil}, # Catalan (Spain)
    {ident: "en-AU", name: "English", language: "en", region: "AU", fallback: nil}, # English (Australia)
    {ident: "en-GB", name: "English", language: "en", region: "GB", fallback: nil}, # English (United Kingdom)
    {ident: "es", name: "Español", language: "es", region: "CL", fallback: "es-ES"}, # Spanish (Chile)
    {ident: "fr-CA", name: "Français", language: "fr", region: "CA", fallback: "fr"}, # French (Canada)
    {ident: "hr", name: "Hrvatski", language: "hr", region: "HR", fallback: nil}, # Croatian (Croatia)
    {ident: "is", name: "íslenska", language: "is", region: "IS", fallback: nil}, # Icelandic (Iceland)
    {ident: "km-KH", name: "ភាសាខ្មែ", language: "km", region: "KH", fallback: nil}, # Khmer (Cambodia)
    {ident: "ms-MY", name: "Bahasa Malaysia", language: "ms", region: "MY", fallback: nil}, # Malay (Malaysia)
    {ident: "pl", name: "Polski", language: "pl", region: "PL", fallback: nil}, # Polish (Poland)
    {ident: "ro", name: "Română", language: "ro", region: "RO", fallback: nil}, # Romanian (Romania)
    {ident: "sw", name: "Kiswahili", language: "sw", region: "KE", fallback: nil}, # Swahili (Kenya)
    {ident: "vi", name: "Tiếng Việt", language: "vi", region: "VN", fallback: nil}, # Vietnamese (Vietnam)
  ]

  AVAILABLE_LOCALES = SUPPORTED_LOCALES.concat(UNSUPPORTED_LOCALES)

  REMOVED_LOCALE_FALLBACKS = {
    # removed 20.5.2015
    "de-bl" => "de",
    "de-rc" => "de",
    "en-bd" => "en",
    "en-bf" => "en",
    "en-bl" => "en",
    "en-cf" => "en",
    "en-rc" => "en",
    "en-sb" => "en",
    "en-ul" => "en",
    "en-un" => "en",
    "en-vg" => "en",
    "es-rc" => "es",
    "fr-bd" => "fr",
    "fr-rc" => "fr",

    # removed 21.5.2015
    "en-qr" => "en",
    "en-at" => "en",
    "fr-at" => "fr"
  }

  REMOVED_LOCALES = REMOVED_LOCALE_FALLBACKS.keys.to_set
end
