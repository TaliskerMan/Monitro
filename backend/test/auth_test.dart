// Auth-decision tests for the Monitro API server.
import 'package:test/test.dart';
import 'package:monitro_collector/api/server.dart';

void main() {
  const key = 'secret-key';

  group('isRequestAuthorized', () {
    test('health is always allowed (no key needed)', () {
      expect(
        isRequestAuthorized(
          method: 'GET', path: 'api/v1/health', authHeader: null, apiKey: key),
        isTrue,
      );
    });

    test('CORS preflight is allowed', () {
      expect(
        isRequestAuthorized(
          method: 'OPTIONS', path: 'api/v1/processes', authHeader: null, apiKey: key),
        isTrue,
      );
    });

    test('data endpoints require the correct bearer key', () {
      expect(
        isRequestAuthorized(
          method: 'GET', path: 'api/v1/metrics/current', authHeader: null, apiKey: key),
        isFalse,
      );
      expect(
        isRequestAuthorized(
          method: 'GET', path: 'api/v1/metrics/current',
          authHeader: 'Bearer wrong', apiKey: key),
        isFalse,
      );
      expect(
        isRequestAuthorized(
          method: 'GET', path: 'api/v1/metrics/current',
          authHeader: 'Bearer $key', apiKey: key),
        isTrue,
      );
    });

    test('the kill endpoint is not reachable without the key', () {
      expect(
        isRequestAuthorized(
          method: 'DELETE', path: 'api/v1/processes/1234',
          authHeader: null, apiKey: key),
        isFalse,
      );
    });
  });
}
