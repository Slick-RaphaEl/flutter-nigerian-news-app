import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:first_app/helper/sharedpref_helper.dart';

class DatabaseMethods {
  Future addUserInfoToDB(
      String userId, Map<String, dynamic> userInfoMap) async {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .set(userInfoMap);
  }

  //  ADD PLACES TO DB
  Future addPlaceInfoToDB(
      String userId, Map<String, dynamic> placeInfoMAP) async {
    return FirebaseFirestore.instance
        .collection("places")
        .doc(userId)
        .set(placeInfoMAP);
  }

  // GET PLACES FROM DB
  Future<Stream<QuerySnapshot>> getPlaceDetailsList() async {
    String myEmail = await SharedPreferenceHelper().getUserEmail();
    return FirebaseFirestore.instance
        .collection("places")
        .where("email", isEqualTo: myEmail)
        .snapshots();
  }
}
