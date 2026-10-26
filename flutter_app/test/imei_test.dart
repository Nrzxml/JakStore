import 'package:flutter_test/flutter_test.dart';
import 'package:jakstore_admin/utils/imei.dart';

void main() {
  group('IMEI barcode parsing', () {
    test('accepts a valid 15-digit IMEI with surrounding whitespace', () {
      final result = parseImeiBarcode('\t 490154203237518 \r\n');

      expect(result.isValid, isTrue);
      expect(result.value, '490154203237518');
      expect(result.error, isNull);
    });

    test('rejects empty barcode values with a clear reason', () {
      expect(parseImeiBarcode(null).error, ImeiParseError.empty);
      expect(parseImeiBarcode(' \t\r\n').error, ImeiParseError.empty);
    });

    test('rejects barcode values that are not exactly 15 digits', () {
      expect(
        parseImeiBarcode('EAN-13: 1234567890123').error,
        ImeiParseError.format,
      );
      expect(
        parseImeiBarcode('49015420323751').error,
        ImeiParseError.format,
      );
      expect(
        parseImeiBarcode('490154203237 518').error,
        ImeiParseError.format,
      );
    });

    test('rejects an invalid IMEI check digit', () {
      expect(
        parseImeiBarcode('490154203237519').error,
        ImeiParseError.checksum,
      );
    });
  });
}
