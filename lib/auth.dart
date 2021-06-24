import 'dart:async';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Auth with ChangeNotifier {
  String _token;
  DateTime _expiryDate;
  String _userId;
  Timer authTimer;

  bool get isAuth {
    return token != null;
  }

  String get token {
    if (_token != null &&
        _expiryDate != null &&
        _expiryDate.isAfter(DateTime.now())) {
      return _token;
    }
    return null;
  }

  Future<void> _authanticate(
      String email, String password, String urlPath) async {
    final url =
        'https://identitytoolkit.googleapis.com/v1/accounts:$urlPath?key=AIzaSyB6lOXAgJKJbpM2jbw4BaRuizdtFv5Q_fc';

    try {
      final res = await http.post(Uri.parse(url),
          body: json.encode({
            "email": email,
            "password": password,
            "returnSecureToken": true,
          }));
      final resData = json.decode(res.body);

      if (resData['error'] != null) {
        throw "${resData['error']['message']}";

      }
      _token = resData['idToken'];
      _userId = resData['localId'];
      _expiryDate = DateTime.now()
          .add(Duration(seconds: int.parse(resData['expiresIn'])));

      final pref = await SharedPreferences.getInstance();
      final userData = json.encode({
        'token': _token,
        'userId': _userId,
        'expiryDate': _expiryDate.toIso8601String(),
      });
      pref.setString("userData", userData);

      autoLogOut();
      notifyListeners();
    } catch (error) {
      throw error;
    }
  }
  
  Future<bool> autoLogIn() async {
    final pref = await SharedPreferences.getInstance();
    if(!pref.containsKey('userData'))
      return false;

    final exteractedData = json.decode(pref.getString('userData')) as Map<String, Object>;
    final expiryData = DateTime.parse(exteractedData['expiryDate']);

    if(expiryData.isBefore(DateTime.now()))
      return false;

    _token = exteractedData['token'];
    _userId = exteractedData['userId'];
    _expiryDate = expiryData;
    notifyListeners();
    autoLogOut();
    return true;

  }

  Future<void> signUp(String email, String password) async {
    return _authanticate(email, password, "signUp");
  }

  Future<void> logIn(String email, String password) async {
    return _authanticate(email, password, "signInWithPassword");
  }

  Future<void> logOut() async{
    _token = null;
    _userId = null;
    _expiryDate = null;
    if (authTimer != null) {
      authTimer.cancel();
      authTimer = null;
    }
    notifyListeners();
    final pref = await SharedPreferences.getInstance();
    pref.clear();
  }

  void autoLogOut() {
    if (authTimer != null) {
      authTimer.cancel();
    }
    var timeToExpiry = _expiryDate.difference(DateTime.now()).inSeconds;
    authTimer = Timer(
        Duration(
          seconds: timeToExpiry,
        ),
        logOut);
  }
}
