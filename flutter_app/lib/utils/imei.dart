enum ImeiParseError { empty, format, checksum }

class ImeiParseResult {
  const ImeiParseResult._(this.value, this.error);

  const ImeiParseResult.valid(String value) : this._(value, null);

  const ImeiParseResult.invalid(ImeiParseError error) : this._(null, error);

  final String? value;
  final ImeiParseError? error;

  bool get isValid => value != null;
}

ImeiParseResult parseImeiBarcode(String? rawValue) {
  final normalized = rawValue?.trim() ?? '';
  if (normalized.isEmpty) {
    return const ImeiParseResult.invalid(ImeiParseError.empty);
  }
  if (!RegExp(r'^[0-9]{15}$').hasMatch(normalized)) {
    return const ImeiParseResult.invalid(ImeiParseError.format);
  }
  if (!isValidImei(normalized)) {
    return const ImeiParseResult.invalid(ImeiParseError.checksum);
  }
  return ImeiParseResult.valid(normalized);
}

bool isValidImei(String value) {
  if (!RegExp(r'^[0-9]{15}$').hasMatch(value)) return false;
  var sum = 0;
  for (var index = 0; index < value.length; index++) {
    var digit = int.parse(value[index]);
    if (index.isOdd) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  return sum % 10 == 0;
}

extension ImeiParseErrorMessage on ImeiParseError {
  String get message => switch (this) {
        ImeiParseError.empty => 'Barcode tidak berisi teks IMEI.',
        ImeiParseError.format =>
          'Barcode bukan IMEI 15 digit. Gunakan barcode IMEI, bukan barcode produk.',
        ImeiParseError.checksum =>
          'Checksum IMEI tidak valid. Periksa barcode dan coba lagi.',
      };
}
