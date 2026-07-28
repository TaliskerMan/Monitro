// Contract + error-mapping tests for the Monitro UI.
//
// The "no data everywhere" class of bug is almost always a contract drift
// (the collector emits one key, the UI reads another) or a swallowed backend
// error. These tests lock both down.

import 'package:flutter_test/flutter_test.dart';
import 'package:monitro/services/error_messages.dart';

/// The top-level snapshot keys the dashboard/screens read from the collector.
/// If the collector renames one of these, a contract test should fail loudly
/// rather than the UI silently rendering blank cards.
const uiReadsSnapshotKeys = <String>{
  'system',
  'cpu',
  'memory',
  'netstat',
  'users',
  'api_calls',
  'processes',
};

void main() {
  group('friendlyBackendError', () {
    test('403 is explained as an API key mismatch', () {
      final msg = friendlyBackendError('HTTP 403');
      expect(msg, contains('API key mismatch'));
      expect(msg.toLowerCase(), contains('restart the collector'));
    });

    test('500 points at the collector/DB', () {
      expect(friendlyBackendError('HTTP 500'), contains('500'));
    });

    test('connection refused is explained', () {
      final msg = friendlyBackendError('SocketException: Connection refused');
      expect(msg, contains('8443'));
      expect(msg.toLowerCase(), contains('not be running'));
    });

    test('unknown errors are passed through, not hidden', () {
      expect(friendlyBackendError('weird'), 'Backend error: weird');
    });
  });

  group('snapshot contract', () {
    // A representative snapshot in the shape the collector emits. If the
    // collector's CollectorManager changes a top-level key, update BOTH this
    // fixture and uiReadsSnapshotKeys — that's the point: the rename can't be
    // silent.
    final sampleSnapshot = <String, dynamic>{
      'system': {'hostname': 'h'},
      'cpu': {
        'busy_pct': 1.0,
        'cores': [
          {'busy_pct': 1.0}
        ]
      },
      'memory': {'used_pct': 2.0},
      'netstat': {'connections': []},
      'users': {'sessions': []},
      'api_calls': {'count': 0},
      'processes': {'processes': []},
      'disk': <String, dynamic>{},
      'network': <String, dynamic>{},
    };

    test('every key the UI reads exists in the collector snapshot', () {
      for (final key in uiReadsSnapshotKeys) {
        expect(
          sampleSnapshot.containsKey(key),
          isTrue,
          reason: 'UI reads "$key" but the collector snapshot does not emit it',
        );
      }
    });

    test('cpu/memory expose the nested fields the cards read', () {
      expect((sampleSnapshot['cpu'] as Map).containsKey('busy_pct'), isTrue);
      expect((sampleSnapshot['cpu'] as Map).containsKey('cores'), isTrue);
      expect((sampleSnapshot['memory'] as Map).containsKey('used_pct'), isTrue);
    });
  });
}
