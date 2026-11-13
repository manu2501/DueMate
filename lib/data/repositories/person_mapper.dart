import '../../domain/entities/person.dart' as domain;
import '../database/app_database.dart' as db;

/// The one place a `persons` row becomes a domain [domain.Person]. Every
/// repository uses it, so a new column is mapped once.
extension PersonRowToDomain on db.Person {
  domain.Person toDomain() => domain.Person(
        id: id,
        name: name,
        phone: phone,
        email: email,
        notes: notes,
        upiId: upiId,
        avatarPath: avatarPath,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      );
}
