import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:first_app/models/address.dart';

class AppData extends ChangeNotifier {
  Address selectedLocation;

  void updateSelectedLocationAddress(Address selectedAddress) {
    selectedLocation = selectedAddress;
    notifyListeners();
  }
}
