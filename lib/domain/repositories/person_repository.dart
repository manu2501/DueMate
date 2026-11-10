import '../entities/person.dart';

abstract class PersonRepository {
  Stream<List<Person>> watchAllPersons({bool includeArchived = false});
  Stream<Person?> watchPersonById(String id);
  Future<List<Person>> getAllPersons({bool includeArchived = false});
  Future<Person?> getPersonById(String id);
  Future<void> createPerson(Person person);
  Future<void> updatePerson(Person person);
  Future<void> archivePerson(String id);
  Future<void> unarchivePerson(String id);
  Future<void> deletePerson(String id);
}

