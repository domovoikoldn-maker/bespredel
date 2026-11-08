import 'package:bespredel/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('парсинг vless reality', () {
    final s = parseVless(
        'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=reality&sni=www.microsoft.com&pbk=AbCd&sid=01&fp=chrome&type=tcp&flow=xtls-rprx-vision#%D0%A2%D0%B5%D1%81%D1%82');
    expect(s, isNotNull);
    expect(s!.host, 'example.com');
    expect(s.port, 443);
    expect(s.isReality, isTrue);
    expect(s.valid, isTrue);
    expect(s.name, 'Тест');
  });
}
