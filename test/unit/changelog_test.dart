import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/domain/changelog.dart';

void main() {
  group('Changelog.parse', () {
    const sample = '''
# Changelog

Intro text, and a list that is not a release:
- ignored

## 1.2.0+3 · 2026-12-01

### New
- First thing.
- A longer line that
  carries on here.

### Fixed
- A fix.

## Unreleased

### New
- Not a version heading, so skipped.

## 1.1.0+2 · 2026-11-13

### Improved
- Better.

### Empty
''';

    test('reads releases newest first, with sections and items', () {
      final releases = Changelog.parse(sample);
      expect(releases.map((r) => r.version), ['1.2.0', '1.1.0']);

      final latest = releases.first;
      expect((latest.build, latest.date, latest.label), (3, DateTime(2026, 12, 1), '1.2.0 (build 3)'));
      expect(latest.sections.map((s) => s.title), ['New', 'Fixed']);
      expect(latest.sections.first.items, ['First thing.', 'A longer line that carries on here.']);
    });

    test('skips intro text, non-version headings and empty sections', () {
      final older = Changelog.parse(sample).last;
      expect(older.sections.map((s) => s.title), ['Improved']);
      expect(Changelog.parse('# Changelog\n\n- nothing here\n'), isEmpty);
    });

    test('a release without a date still parses', () {
      expect(Changelog.parse('## 2.0.0+9\n### New\n- x\n').single.date, isNull);
    });
  });

  group('the shipped CHANGELOG.md', () {
    final releases = Changelog.parse(File('CHANGELOG.md').readAsStringSync());

    test('its newest release is this version, as in pubspec.yaml and AppConstants', () {
      final pubspec = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
          .firstMatch(File('pubspec.yaml').readAsStringSync())!
          .group(1);
      final current = '${AppConstants.appVersion}+${AppConstants.appBuildNumber}';
      expect(pubspec, current, reason: 'pubspec.yaml version');
      expect('${releases.first.version}+${releases.first.build}', current, reason: 'newest CHANGELOG.md entry');
      expect(AppConstants.appVersionString, 'v$current');
    });

    test('every release has notes, and versions, builds and dates only go back in time', () {
      for (final r in releases) {
        expect(r.sections.expand((s) => s.items), isNotEmpty, reason: '${r.version} has no notes');
        expect(r.date, isNotNull, reason: '${r.version} has no date');
      }
      for (var i = 1; i < releases.length; i++) {
        final (newer, older) = (releases[i - 1], releases[i]);
        expect(newer.build, greaterThan(older.build), reason: 'build numbers must increase');
        expect(newer.date!.isBefore(older.date!), isFalse, reason: '${newer.version} dated before ${older.version}');
      }
    });
  });
}
