class AppUser {
  final String uid;
  final String email;
  final String name;
  final bool isAdmin;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.isAdmin = false,
  });

  // convert app usert to json
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'isAdmin': isAdmin,
    };
  }

  // convert json to app usert
  factory AppUser.fromJson(Map<String, dynamic> jsonUser) {
    return AppUser(
      uid: jsonUser['uid'],
      email: jsonUser['email'],
      name: jsonUser['name'],
      isAdmin: jsonUser['isAdmin'] == true,
    );
  }
}
