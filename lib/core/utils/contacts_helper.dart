import 'package:flutter_contacts/flutter_contacts.dart';

class ContactData {
  final String name;
  final String? phone;
  final String? email;

  ContactData({
    required this.name,
    this.phone,
    this.email,
  });
}

class ContactsHelper {
  /// Request read permission
  static Future<bool> requestPermission() async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      return status == PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  /// Open native Android contact picker and return selected contact
  static Future<ContactData?> pickContact() async {
    try {
      // showPicker invokes native Android contact picker
      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.name, ContactProperty.phone, ContactProperty.email},
      );
      if (contact == null) return null;

      final dispName = contact.displayName?.trim() ?? '';
      final firstName = contact.name?.first?.trim() ?? '';
      final lastName = contact.name?.last?.trim() ?? '';
      final fullName = '$firstName $lastName'.trim();

      final name = dispName.isNotEmpty ? dispName : fullName;
      final phone = contact.phones.isNotEmpty ? contact.phones.first.number.trim() : null;
      final email = contact.emails.isNotEmpty ? contact.emails.first.address.trim() : null;

      if (name.isEmpty && (phone == null || phone.isEmpty)) {
        return null;
      }

      return ContactData(
        name: name.isNotEmpty ? name : (phone ?? 'Contact'),
        phone: phone,
        email: email,
      );
    } catch (e) {
      return null;
    }
  }

  /// Fetch device contacts with phone numbers for in-app picker/search
  static Future<List<ContactData>> getAllContacts() async {
    try {
      final hasPerm = await FlutterContacts.permissions.has(PermissionType.read);
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) return [];
      }

      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone, ContactProperty.email},
      );

      final List<ContactData> result = [];
      for (final c in contacts) {
        final dispName = c.displayName?.trim() ?? '';
        final firstName = c.name?.first?.trim() ?? '';
        final lastName = c.name?.last?.trim() ?? '';
        final fullName = '$firstName $lastName'.trim();
        final name = dispName.isNotEmpty ? dispName : fullName;

        final phone = c.phones.isNotEmpty ? c.phones.first.number.trim() : null;
        final email = c.emails.isNotEmpty ? c.emails.first.address.trim() : null;

        if (name.isNotEmpty) {
          result.add(ContactData(name: name, phone: phone, email: email));
        }
      }

      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return result;
    } catch (e) {
      return [];
    }
  }
}
