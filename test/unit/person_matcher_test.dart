import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/person_matcher.dart';

Person _p(String id, String name, [String? phone]) => Person(
      id: id,
      name: name,
      phone: phone,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  final rahulA = _p('a', 'Rahul', '+91 98765 43210');
  final priya = _p('b', 'Priya');

  test('normalizePhone keeps the last 10 digits', () {
    expect(PersonMatcher.normalizePhone('+91 98765-43210'), '9876543210');
    expect(PersonMatcher.normalizePhone(null), '');
  });

  test('same number in a different format is a duplicate', () {
    expect(PersonMatcher.findDuplicate([rahulA], name: 'R K', phone: '9876543210'), rahulA);
  });

  test('same name, different numbers: not a duplicate', () {
    expect(PersonMatcher.findDuplicate([rahulA], name: 'Rahul', phone: '9123456780'), isNull);
  });

  test('same name when one side has no number: duplicate', () {
    expect(PersonMatcher.findDuplicate([priya], name: ' priya ', phone: '9123456780'), priya);
    expect(PersonMatcher.findDuplicate([rahulA], name: 'Rahul'), rahulA);
  });

  test('the person being edited is ignored', () {
    expect(PersonMatcher.findDuplicate([rahulA], name: 'Rahul', excludeId: 'a'), isNull);
  });

  test('a phone match wins over an earlier name match', () {
    final rahulNoPhone = _p('c', 'Rahul');
    final other = _p('d', 'Someone', '9876543210');
    expect(
      PersonMatcher.findDuplicate([rahulNoPhone, other], name: 'Rahul', phone: '9876543210'),
      other,
    );
  });
}
