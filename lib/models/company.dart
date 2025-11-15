
class Company {
  final int? id;
  final String name;
  final String? contactPerson;
  final String? address;
  final String? phone;
  final String? email;
  final String? gstin;

  Company({this.id, required this.name, this.contactPerson, this.address, this.phone, this.email, this.gstin});

  factory Company.fromMap(Map<String, Object?> m) => Company(
    id: m['id'] as int?,
    name: m['name'] as String,
    contactPerson: m['contact_person'] as String?,
    address: m['address'] as String?,
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    gstin: m['gstin'] as String?,
  );
}
