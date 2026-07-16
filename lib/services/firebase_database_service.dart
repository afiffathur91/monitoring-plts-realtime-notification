import 'package:firebase_database/firebase_database.dart';

class FirebaseDatabaseService {
  static final FirebaseDatabaseService _instance = FirebaseDatabaseService._internal();
  factory FirebaseDatabaseService() => _instance;
  FirebaseDatabaseService._internal() {
    // Set the correct database URL for Asia Southeast 1 region
    FirebaseDatabase.instance.databaseURL = 'https://mobile-plts-afif-default-rtdb.asia-southeast1.firebasedatabase.app';
  }

  DatabaseReference get devicesRef => FirebaseDatabase.instance.ref('devices');

  DatabaseReference deviceRef(String deviceId) {
    return FirebaseDatabase.instance.ref('devices/$deviceId');
  }

  DatabaseReference deviceDataRef(String deviceId) {
    return FirebaseDatabase.instance.ref('devices/$deviceId/data');
  }
}