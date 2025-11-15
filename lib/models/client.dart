
class Client {
  final int? id;
  final String name;
  final String? company;
  final String? email;
  final String? phone;
  final String? address;

  Client({this.id, required this.name, this.company, this.email, this.phone, this.address});

  factory Client.fromMap(Map<String, Object?> m) => Client(
    id: m['id'] as int?,
    name: m['name'] as String,
    company: m['company'] as String?,
    email: m['email'] as String?,
    phone: m['phone'] as String?,
    address: m['address'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'company': company,
    'email': email,
    'phone': phone,
    'address': address,
  };
}
