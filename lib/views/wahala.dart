import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:first_app/secret.dart';
import 'package:first_app/helper/sharedpref_helper.dart';
import 'package:first_app/services/database.dart';
import 'package:first_app/models/place-prediction.dart';
import 'package:first_app/models/address.dart';

class WahalaWatch extends StatefulWidget {
  @override
  _WahalaWatchState createState() => _WahalaWatchState();
}

class _WahalaWatchState extends State<WahalaWatch> {
  bool isSearching = false;
  String myName, myProfilePic, myUserName, myEmail, uid;
  Stream placeListStream;

  TextEditingController searchLocationEditingController =
      TextEditingController();

  List<PlacePredictions> placePredictionList = [];

  getMyInfoFromSharedPreference() async {
    uid = await SharedPreferenceHelper().getUserId();
    myName = await SharedPreferenceHelper().getDisplayName();
    myProfilePic = await SharedPreferenceHelper().getUserProfileUrl();
    myUserName = await SharedPreferenceHelper().getUserName();
    myEmail = await SharedPreferenceHelper().getUserEmail();
    setState(() {});
  }

  Future<void> findPlace(String placeName) async {
    if (placeName.length > 1) {
      String autoCompleteUrl =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$placeName&key=$googleMapKey&sessiontoken=1234567890&components=country:ng";

      var data = await http.get(Uri.parse(autoCompleteUrl));
      var response = jsonDecode(data.body);

      print("response =");
      print(response);

      if (response["predictions"] != null) {
        var predictions = response["predictions"];
        print("predictions =");
        print(predictions);
        var placeList = (predictions as List)
            .map((e) => PlacePredictions.fromJson(e))
            .toList();

        setState(() {
          placePredictionList = placeList;
        });
      }
    }
  }

  getPlaceList() async {
    placeListStream = await DatabaseMethods().getPlaceDetailsList();
    setState(() {});
  }

  onScreenLoaded() async {
    await getMyInfoFromSharedPreference();
    getPlaceList();
  }

  @override
  void initState() {
    onScreenLoaded();
    super.initState();
  }

  Widget placesList() {
    return StreamBuilder(
        stream: placeListStream,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? ListView.builder(
                  itemCount: snapshot.data.docs.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    DocumentSnapshot ds = snapshot.data.docs[index];
                    return SavedPlacesListTile(ds["placename"], ds["tags"]);
                  })
              : Center(
                  child: CircularProgressIndicator(),
                );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Info Ninja")),
      body: Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              isSearching
                  ? GestureDetector(
                      onTap: () {
                        isSearching = false;
                        searchLocationEditingController.text = "";
                        setState(() {});
                      },
                      child: Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.arrow_back),
                      ),
                    )
                  : Container(),
              Container(
                margin: EdgeInsets.symmetric(vertical: 16),
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.grey, width: 1, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          findPlace(val);
                        },
                        controller: searchLocationEditingController,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Search Location"),
                      ),
                    ),
                    GestureDetector(
                        onTap: () {
                          // if (searchLocationEditingController.text != "") {
                          //   onSearchBtnClick();
                          // }
                          isSearching = true;
                          setState(() {});
                        },
                        child: Icon(Icons.search))
                  ],
                ),
              ),
              // widget for locations

              SizedBox(
                height: 10.0,
              ),
              (placePredictionList.length > 0)
                  ? Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: ListView.separated(
                        padding: EdgeInsets.all(0.0),
                        itemBuilder: (context, index) {
                          return PredictionTile(
                            placePredictions: placePredictionList[index],
                          );
                        },
                        separatorBuilder: (BuildContext context, int index) =>
                            Divider(),
                        itemCount: placePredictionList.length,
                        shrinkWrap: true,
                        physics: ClampingScrollPhysics(),
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}

class PredictionTile extends StatelessWidget {
  final PlacePredictions placePredictions;
  PredictionTile({Key key, this.placePredictions}) : super(key: key);

  void getPlacePredictionAddressAndAddToDB(String placeId, context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) => Center(
        child: CircularProgressIndicator(),
      ),
    );
    String placeDetailsUrl =
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$googleMapKey";

    var data = await http.get(Uri.parse(placeDetailsUrl));
    var res = jsonDecode(data.body);
    print("place details =");
    print(res);

    Navigator.pop(context);

    if (res == "failed") {
      return;
    }

    if (res["status"] == "OK") {
      var uid = await SharedPreferenceHelper().getUserId();
      var postalCode;
      var city;
      var state;
      Address address = Address();
      address.placeName = res["result"]["name"];
      address.placeId = placeId;
      address.latitude = res["result"]["geometry"]["location"]["lat"];
      address.longitude = res["result"]["geometry"]["location"]["lng"];

      var data = res["result"];
      var addressComponents = data["address_components"];
      for (var i = 0; i < addressComponents.length; i++) {
        var typesArray = addressComponents[i]["types"];
        for (int j = 0; j < typesArray.length; j++) {
          if (typesArray[j].toString() == "postal_code") {
            postalCode = addressComponents[i].getString("long_name");
          }
          if (typesArray[j].toString() == "locality") {
            city = addressComponents[i]["long_name"];
          }
        }
      }


      Map<String, dynamic> placeInfoMap = {
        "name": address.placeName,
        "city": city,
        "placeid": placeId,
        "postalcode": postalCode,
        "state": state,
      };

      DatabaseMethods().addPlaceInfoToDB(uid, placeInfoMap).then((value) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => WahalaWatch()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: TextButton(
        onPressed: () {
          getPlacePredictionAddressAndAddToDB(
              placePredictions.place_id, context);
        },
        child: Container(
          child: Column(
            children: [
              SizedBox(
                width: 10.0,
              ),
              Row(
                children: [
                  Icon(Icons.add_location),
                  SizedBox(
                    width: 14.0,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 8.0,
                        ),
                        Text(
                          placePredictions.main_text,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16.0),
                        ),
                        SizedBox(
                          height: 2.0,
                        ),
                        Text(
                          placePredictions.secondary_text,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.0),
                        ),
                        SizedBox(
                          height: 8.0,
                        ),
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class SavedPlacesListTile extends StatefulWidget {
  final String placeName;
  final int status;
  SavedPlacesListTile(this.placeName, this.status);

  @override
  _SavedPlacesListTileState createState() => _SavedPlacesListTileState();
}

class _SavedPlacesListTileState extends State<SavedPlacesListTile> {
  String placeName;
  int status;

  Widget statusWidget() {
    if (status <= 5) {
      return Container(
        height: 20,
        width: 30,
        decoration: BoxDecoration(color: Colors.green),
      );
    }

    if (status > 5 && status <= 10) {
      return Container(
        height: 20,
        width: 30,
        decoration: BoxDecoration(color: Colors.yellow),
      );
    }

    if (status > 10) {
      return Container(
        height: 20,
        width: 30,
        decoration: BoxDecoration(color: Colors.red),
      );
    }
    return Container();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                placeName,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 3),
              Row(children: [
                Image.asset('assets/images/police.png'),
                Icon(Icons.health_and_safety_rounded),
                Icon(Icons.comment),
              ])
            ],
          ),
          statusWidget(),
        ],
      ),
    );
  }
}
