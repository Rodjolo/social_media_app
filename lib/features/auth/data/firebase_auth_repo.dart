import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socail_media_app/features/auth/domain/entities/app_user.dart';
import 'package:socail_media_app/features/auth/domain/repos/auth_repo.dart';

class FirebaseAuthRepo implements AuthRepo {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;

  @override
  Future<AppUser?> loginWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      // fetch user document from firestore
      DocumentSnapshot userDoc = await firebaseFirestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      AppUser user = AppUser(
        uid: userCredential.user!.uid,
        email: email,
        name: userDoc['name'],
        isAdmin: userDoc.data() is Map<String, dynamic>
            ? ((userDoc.data() as Map<String, dynamic>)['isAdmin'] == true)
            : false,
      );

      return user;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<AppUser?> registerWithEmailPassword(
      String name, String email, String password) async {
    try {
      UserCredential userCredential = await firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      //create user
      AppUser user = AppUser(
        uid: userCredential.user!.uid,
        email: email,
        name: name,
        isAdmin: false,
      );

      //save user data in firestore
      await firebaseFirestore.collection("users").doc(user.uid).set({
        ...user.toJson(),
        'bio': '',
        'profileImageUrl': '',
        'followers': <String>[],
        'following': <String>[],
        'favoriteGenres': <String>[],
        'movieOnboardingCompleted': false,
        'isAdmin': false,
      });

      return user;
    } catch (e) {
      throw Exception('Register failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    await firebaseAuth.signOut();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = firebaseAuth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    // fetch user document from firestore
    DocumentSnapshot userDoc =
        await firebaseFirestore.collection('users').doc(firebaseUser.uid).get();

    if (!userDoc.exists) {
      return null;
    }

    // user exists
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email!,
      name: userDoc['name'],
      isAdmin: userDoc.data() is Map<String, dynamic>
          ? ((userDoc.data() as Map<String, dynamic>)['isAdmin'] == true)
          : false,
    );
  }
}
