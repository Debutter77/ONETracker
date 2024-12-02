import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';

import '../../main.dart';
import '../../rpc_calls/HarmonyService.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';
import 'home_model.dart';
export 'home_model.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
class CustomDialog extends StatelessWidget {
  final Widget content;
  final String title;

  const CustomDialog({super.key, required this.content, required this.title});


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Color(0xFF1D1E33), // Dark background color
          borderRadius: BorderRadius.circular(20.0), // Rounded corners
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFFdbd7fb),
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            content,
          ],
        ),
      ),
    );
  }
}

class HomeWidget extends StatefulWidget {
  const HomeWidget({super.key});


  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> with TickerProviderStateMixin, WidgetsBindingObserver{
  late HomeModel _model;
  Timer? _timer;
  late StreamSubscription subscription;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = SidebarXController(selectedIndex: 0, extended: true);

  final animationsMap = <String, AnimationInfo>{};
  final animationsMap_loop = <String, AnimationInfo>{};

  final String databaseURL =
      'https://harmonyrewards-default-rtdb.europe-west1.firebasedatabase.app';

  bool loading = false;
  bool newAddress = false;
  bool isFavorite = false; // Track whether the address is marked as favorite

  bool setValidatorNotification = true;
  bool setRewardsNotification = true;

  double availableBalance = 0.0;
  double totalOne = 0.0;
  double totalStaked = 0.0;
  double rewards = 0.0;
  double onePrice = 0.0;
  double totalUSD = 0.0;
  String address_label = "-> Insert your Wallet Address <-";
  String username = "";
  double? rewardThreshold = 0.0;
  String timestamp="";

  int epoch = 0;
  int undelegationepoch = 0;
  int epochsToUndelegat = 0;
  double? undelegationAmount=0.0;
  bool undelegation = false;

  double opacity = 1.0; //ONE Price Opacity
  double alertOpacity = 0.0; //Alert Icon Opacity

  //Lists and my Map
  List<String> myDelegatorList = [];
  ValueNotifier<List<String>> addressListHistory = ValueNotifier([]);
  ValueNotifier<Map<String, dynamic>> favoriteAddressMap = ValueNotifier({});


  List<Map<String, dynamic>> userAddresses = [];
  late StreamSubscription<ConnectivityResult> connectivityPlus;
////////////////////////////////////////////////////////////////////////////////////////////////////

  Future<bool> _checkWalletExistens(String favWallatAddress) async {
    HarmonyService harmonyService =
        HarmonyService('https://rpc.s0.t.hmny.io'); // Harmony One RPC URL
    harmonyService.setAddress(favWallatAddress);
    try {
      await harmonyService.getBalance();
      double availableBalance = harmonyService.availableBalance;

      if (availableBalance == 0) {
        return false;
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDelegationsInfo(String delegatorAddress, List<String> delegations) async {
    final Uri apiUrl = Uri.parse(
        'https://europe-west1-harmonyrewards.cloudfunctions.net/api/getDelegationsInfo/$delegatorAddress?delegations=${Uri.encodeComponent(jsonEncode(delegations))}');

    final response = await http.get(apiUrl);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['delegations']);
    } else {
      throw Exception('Failed to load delegations info');
    }
  }

  void showDelegationsDialog(BuildContext context, String delegatorAddress, List<String> delegations) async {
    try {
      List<Map<String, dynamic>> delegationsInfo = await fetchDelegationsInfo(delegatorAddress, delegations);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: Color(0xFF1D1E33),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog Title
                  Text(
                    'Current Delegations',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Delegations Table
                  Table(
                    border: TableBorder.all(color: Colors.tealAccent, width: 1),
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.2)),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Validator Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Staked (ONE)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Rewards (ONE)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...delegationsInfo.map((info) {
                        return TableRow(
                          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(info['name'] ?? 'Unknown', style: TextStyle(color: Colors.white)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('${info['stakedAmount']?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: Colors.white)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('${info['rewards']?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: Colors.white)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                info['isElected'] ? 'Elected' : 'Not Elected',
                                style: TextStyle(color: info['isElected'] ? Colors.greenAccent : Colors.redAccent),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Close Button
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black, backgroundColor: Colors.tealAccent, // Text color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10), // Rounded button
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0),
                        child: Text(
                          'Close',
                          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Error fetching delegation info: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load delegations')));
    }
  }
  Future<void> _getEpochsUntilUndelegation() async{
    HarmonyService harmonyService = HarmonyService('https://rpc.s0.t.hmny.io');
    await harmonyService.getEpoch();
    setState(() {
      if(undelegation){
        epoch = harmonyService.epoch_now;
        epochsToUndelegat = undelegationepoch -  epoch + 7;
        undelegationAmount = harmonyService.undelegationAmount;
      }
    });
  }

  void _getAccountInfo() async {
    loading = true;
    HarmonyService harmonyService =
        HarmonyService('https://rpc.s0.t.hmny.io'); // Harmony One RPC URL
    harmonyService.setAddress(address_label);
    try {
      await harmonyService.getBalance();
      await harmonyService.getValidators();
      await harmonyService.getTotaSumOfTokens();
      await harmonyService.getPriceOfOneToken();
      await harmonyService.getTotalUSD();
      undelegation = harmonyService.undelegation;
      undelegationepoch  = harmonyService.undelegation_epoch;
      _getEpochsUntilUndelegation();
      if (!newAddress) loadAlertIcon();
      setState(() {
        timestamp = "Refreshed: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.timestamp())}";
        totalStaked = harmonyService.totalStaked;
        rewards = harmonyService.rewards;
        availableBalance = harmonyService.availableBalance;
        if (availableBalance == 0 ) {
          toastification.show(
            context: context,
            // optional if you use ToastificationWrapper
            style: ToastificationStyle.fillColored,
            type: ToastificationType.error,
            title: Text('Wallet address is invalid or does not exist.'),
            autoCloseDuration: const Duration(seconds: 7),
          );
          setState(() {
            address_label = "-> Insert your Wallet Address <-";
            loading = false;
          });
          return;
        }
        totalOne = harmonyService.totalOne;
        onePrice = harmonyService.onePrice;
        totalUSD = harmonyService.totalUSD;
        _saveCurrentAddress(address_label);
        _savelastAddresses(address_label);
        loading = false;
        myDelegatorList = harmonyService.getmyDelegatorList();
      });
    } catch (error) {
      toastification.show(
        context: context,
        style: ToastificationStyle.fillColored,
        type: ToastificationType.error,
        title: Text('Wallet address is invalid or does not exist.'),
        autoCloseDuration: const Duration(seconds: 7),
      );
      setState(() {
        address_label = "-> Insert your Wallet Address <-";
        loading = false;
      });
    }
  }


  Future<void> updateWalletAlerts(String address, double newRewardsThresshold ,bool rewardsNotification, bool validatorNotification) async{
    final fcmToken = await FirebaseMessaging.instance.getToken();
    try {
      await sendUserData(
        uid: username,
        fcmToken: fcmToken!,
        address: address,
        rewardsTrigger: newRewardsThresshold,
        setRewardsNotification: rewardsNotification,
        setValidatorNotification: validatorNotification,
      );
      print('rewardsTrigger updated for user: $username');
    }catch(e){
      print(e);
    }
  }


  Future<void> saveUserFCMTokenRewardstriggerValidatorAlertToDatabase(
      String address, double rewardsTrigger) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();

    print('fcmtoken: $fcmToken');
    // Eindeutigen Benutzer-ID generieren
    String userId = "";
    try {
      if (username.isEmpty) {
        // Generate a random user ID
        userId = _generateRandomUserId();
        await sendUserData(
          uid: userId,
          fcmToken: fcmToken!,
          address: address,
          rewardsTrigger: rewardsTrigger,
          setRewardsNotification: setRewardsNotification,
          setValidatorNotification: setValidatorNotification,
        );
        _saveUsername(userId);
        username = userId;
        // Print confirmation
        print('Token, rewardsTrigger and address saved for user: $userId');
      } else {
        await sendUserData(
          uid: username,
          fcmToken: fcmToken!,
          address: address,
          rewardsTrigger: rewardsTrigger,
          setRewardsNotification: setRewardsNotification,
          setValidatorNotification: setValidatorNotification,
        );
        print('rewardsTrigger updated for user: $username');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> deleteUserFromDB(String uid) async {
    final response = await http.post(
      Uri.parse(
          'https://europe-west1-harmonyrewards.cloudfunctions.net/api/deleteUser'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'uid': uid,
      }),
    );
    if (response.statusCode == 200) {
      print('User deleted successfully.');
    } else {
      print('Failed to delete user: ${response.body}');
    }
  }



  Future<void> deleteAddressFromDB(String uid, String address) async {
    final response = await http.post(
      Uri.parse(
          'https://europe-west1-harmonyrewards.cloudfunctions.net/api/deleteAddress'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'uid': uid,
        'address': address,
      }),
    );
    if (response.statusCode == 200) {
      print('Address deleted successfully.');
    } else {
      print('Failed to delete address: ${response.body}');
    }
  }


///////////////////////////////////////////////////////////////////////////////////////////////////////////

  /** In diesem Bereich gibt es Methoden,  für die Formatierung, passende Darstellung der Zahlen und Reset aller Daten*/
  String _generateRandomUserId() {
    final random = Random();
    final userId = List<int>.generate(10, (index) => random.nextInt(10));
    return userId.join();
  }

  String shortAddress(String addrs) {
    if (addrs.contains("Insert")) {
      return address_label;
    }
    if (addrs.length <= 10) {
      return addrs; // Wenn die Adresse zu kurz ist, nicht kürzen
    }
    String firstPart = addrs.substring(0, 10); // Die ersten 6 Zeichen
    String lastPart =
        addrs.substring(addrs.length - 8); // Die letzten 4 Zeichen

    return '$firstPart...$lastPart'; // Zusammenfügen mit "..."
  }

  String formatDouble(double number) {
    final formatter = NumberFormat('#,##0.00');
    return formatter.format(number);
  }

  void resetGUI() {
    setState(() {
      address_label = "-> Insert your Wallet Address <-";
      alertOpacity = 0.0;
      totalStaked = 0.0;
      rewards = 0.0;
      availableBalance = 0.0;
      totalOne = 0.0;
      onePrice = 0.0;
      totalUSD = 0.0;
    });
  }

  void resetData() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1E33), // Passend zum App-Design
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Text(
            'Reset App',
            style: TextStyle(
              color: const Color(0xFFdbd7fb),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to reset the app? This action will delete all stored data and cannot be undone.',
            style: TextStyle(
              color: Colors.grey[400],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Dialog schließen
              },
              child: Text(
                'No',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.tealAccent.withOpacity(0.1),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Dialog schließen
                // Daten löschen
                _performReset();
              },
              child: Text(
                'Yes',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performReset() {
    setState(() {
      _deleteCurrentAddress();
      _deleteRewardsTrigger();
      _deleteUser();
      _deleteAddressList(setState);
      _deleteFavoriteList(setState);
      myDelegatorList.clear();
      userAddresses.clear();
      resetGUI();
    });
    toastification.show(
      context: context,
      style: ToastificationStyle.fillColored,
      type: ToastificationType.success,
      title: Text('The App has been successfully reset.'),
      autoCloseDuration: const Duration(seconds: 7),
    );
  }


////////////////////////////////////////////////////////////////////////////////

  /** In diesem Bereich werden M */
  Future<void> _saveRewardsTrigger(double trigger) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('rewardTrigger', trigger);
  }

  Future<void> _saveUsername(String text) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', text);
  }

  Future<void> _savelastAddresses(String newItem) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // If the text already exists in the list, return early
    if (addressListHistory.value.contains(newItem)) {
      return;
    }
    /*if(username.isEmpty)
      username = _generateRandomUserId();*/
    final currentList = List<String>.from(addressListHistory.value);
    currentList.add(newItem);
    addressListHistory.value = currentList;

    await prefs.setStringList('addresslist', addressListHistory.value);
  }

  Future<void> _saveCurrentAddress(String text) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('address', text);
  }

  Future<void> _saveFavoriteAddresses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String favoriteAddressesJson = jsonEncode(favoriteAddressMap.value);
    await prefs.setString('favoriteAddressMap', favoriteAddressesJson);
  }

  Future<void> _deleteRewardsTrigger() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getDouble("rewardTrigger") == null) return;
    await prefs.remove('rewardTrigger');
    setState(() {
      rewardThreshold = 0.0;
    });
  }

  Future<void> _deleteCurrentAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString("address") == null) return;
    await prefs.remove('address');
  }

  Future<void> _deleteUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString("user") == null) return;
    String? loadUser = prefs.getString('user');
    setState(() {
      username = "";
    });
    deleteUserFromDB(loadUser!);
    await prefs.remove('user');
  }

  Future<void> _deleteFavoriteList(StateSetter setState) async {
    setState(() {
      favoriteAddressMap.value = {};
    });
    _saveFavoriteAddresses();
  }

  Future<void> _deleteAddressList(StateSetter setState) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getStringList("addresslist") == null) return;

    await prefs.remove('addresslist');

    // Clear the list and update the UI
    setState(() {
      addressListHistory.value = [];
    });
  }

  Future<void> _loadSavedUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? loadUser = prefs.getString('user');
    if (loadUser != null && username.isEmpty) {
      setState(() {
        username = loadUser;
      });
    }
  }

  Future<void> _loadRewardsTrigger() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? rewards = prefs.getDouble('rewardTrigger');
    bool? notificationSent = await checkNotificationsfromDB(username, address_label, "Rewards");
    if (notificationSent == null) {
      return;
    }
    if (rewards != null) {
      setState(() {
        if (notificationSent == true) {
          return;
        }
        rewardThreshold = rewards;
      });
    }
  }

  Future<void> loadFavoriteAddresses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? favoriteAddressesJson = prefs.getString('favoriteAddressMap');

    if (favoriteAddressesJson != null) {
      try {
        Map<String, dynamic> loadedMap = jsonDecode(favoriteAddressesJson);
        favoriteAddressMap.value = Map<String, Map<String, dynamic>>.from(
            loadedMap.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)))
        );
      } catch (e) {
        print('Error decoding favorite addresses: $e');
      }
    }
  }


  Future<void> _loadlastAddresses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? loadAddresslist = prefs.getStringList('addresslist');
    if (loadAddresslist != null) {
      setState(() {
        addressListHistory.value = loadAddresslist;
      });
    }
  }

  Future<void> _loadSavedText() async {
    //final fcmToken = await FirebaseMessaging.instance.getToken();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? loadAddress = prefs.getString('address');
    if (loadAddress != null) {
      setState(() {
        //loading = true;
        address_label = loadAddress;
        _getAccountInfo();
      });
    }/*else if(await fetchUserDetailsByFcmToken(fcmToken!)!=null){
      loadUserData(fcmToken);
    }*/
  }

  Future<void> loadAlertIcon() async {
    bool? notificationSentRewards =
        await checkNotificationsfromDB(username, address_label, "Rewards");
    ;
    bool? notificationSentValidator =
        await checkNotificationsfromDB(username, address_label, "Validator");
    if (notificationSentRewards == null) return;
    if (notificationSentValidator == null) return;

    setState(() {
      if (notificationSentRewards && notificationSentValidator) {
        alertOpacity = 0.0;
        _deleteRewardsTrigger();
      } else {
        alertOpacity = 1.0;
      }
      newAddress = false;
    });
  }

  void showInputAddAddresstoFav() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController _textFieldController = TextEditingController();
        return AlertDialog(
          backgroundColor: Colors.transparent, // Transparent background
          content: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(top: 24),
                decoration: BoxDecoration(
                  color: Color(0xFF1D1E33), // Dark background color
                  borderRadius: BorderRadius.circular(20.0), // Rounded corners
                ),
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter Wallet Address',
                      style: TextStyle(
                        color: const Color(0xFFdbd7fb),
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _textFieldController,
                      style: TextStyle(color: const Color(0xFFdbd7fb)),
                      decoration: InputDecoration(
                        hintText: "e.g., one1xyz...",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Add spacing between the TextField and buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      // Align buttons to the right
                      children: [
                        TextButton(
                          child: Text(
                            'Close',
                            style: TextStyle(color: Colors.tealAccent),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text(
                            'SUBMIT',
                            style: TextStyle(color: Colors.tealAccent),
                          ),
                          onPressed: () async {
                            if (_textFieldController.text.isNotEmpty) {
                              // Handle the submitted text here
                              if (await _checkWalletExistens(
                                  _textFieldController.text)) {
                                String? label = await _promptForLabel(context);
                                if (label != null && label.isNotEmpty) {
                                  setState(() {
                                    favoriteAddressMap.value[
                                        _textFieldController.text] = {
                                      "label": label,
                                      "isFavorite": true
                                    };
                                    //favoriteAddressMap.notifyListeners();
                                  });
                                  _saveFavoriteAddresses();
                                  Navigator.of(context).pop();
                                }
                              } else {
                                toastification.show(
                                  context: context,
                                  // optional if you use ToastificationWrapper
                                  style: ToastificationStyle.fillColored,
                                  type: ToastificationType.error,
                                  title: Text(
                                      'Wallet address is invalid or does not exist.'),
                                  autoCloseDuration: const Duration(seconds: 7),
                                );
                              }
                            } else {
                              toastification.show(
                                context: context,
                                style: ToastificationStyle.fillColored,
                                type: ToastificationType.info,
                                title: Text(
                                    'Put in your wallet address before submitting.'),
                                autoCloseDuration: const Duration(seconds: 7),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showInput() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController _textFieldController = TextEditingController();
        return AlertDialog(
          backgroundColor: Colors.transparent, // Transparent background
          content: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(top: 24),
                decoration: BoxDecoration(
                  color: Color(0xFF1D1E33), // Dark background color
                  borderRadius: BorderRadius.circular(20.0), // Rounded corners
                ),
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter Wallet Address',
                      style: TextStyle(
                        color: const Color(0xFFdbd7fb),
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _textFieldController,
                      style: TextStyle(color: const Color(0xFFdbd7fb)),
                      decoration: InputDecoration(
                        hintText: "e.g., one1xyz...",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Add spacing between the TextField and buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      // Align buttons to the right
                      children: [
                        TextButton(
                          child: Text(
                            'Close',
                            style: TextStyle(color: Colors.tealAccent),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text(
                            'SUBMIT',
                            style: TextStyle(color: Colors.tealAccent),
                          ),
                          onPressed: () async {
                            if (_textFieldController.text.isNotEmpty) {
                              // Handle the submitted text here
                              if (await _checkWalletExistens(
                                  _textFieldController.text)) {
                                address_label = _textFieldController.text;
                                setState(() {
                                  newAddress = true;
                                  alertOpacity = 0.0;
                                  //loading = true;
                                  _deleteRewardsTrigger();
                                  _getAccountInfo();
                                });
                                Navigator.of(context).pop();
                              } else {
                                toastification.show(
                                  context: context,
                                  // optional if you use ToastificationWrapper
                                  style: ToastificationStyle.fillColored,
                                  type: ToastificationType.error,
                                  title: Text(
                                      'Wallet address is invalid or does not exist.'),
                                  autoCloseDuration: const Duration(seconds: 7),
                                );
                              }
                            } else {
                              toastification.show(
                                context: context,
                                style: ToastificationStyle.fillColored,
                                type: ToastificationType.info,
                                title: Text(
                                    'Put in your wallet address before submitting.'),
                                autoCloseDuration: const Duration(seconds: 7),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showNotificationSettingsDialog() async {
    bool? rewardsNotificationsEnabled = false;
    bool? validatorNotificationsEnabled = false;
    TextEditingController rewardsController = TextEditingController();
    double screenHeight = MediaQuery.of(context).size.height;


    String address;
    bool validatorEnabled;
    bool rewardsEnabled;

    // Fetch all addresses for the user
    if (username.isNotEmpty) {

      //Fetch notification settings for all address of a user
     //await fetchAndUpdateUserAddresses(this as StateSetter);

      // Fetch notification settings for the current address in parallel
      final validatorFuture = checkNotificationsfromDB(username, address_label, "Validator");
      final rewardsFuture = checkNotificationsfromDB(username, address_label, "Rewards");

      final results = await Future.wait([validatorFuture, rewardsFuture]);

      validatorNotificationsEnabled = !results[0]!; // Validator setting
      rewardsNotificationsEnabled = !results[1]!; // Rewards setting
      double? rewardsThresholdValue = await getRewardsThreshold(username, address_label);
      // Todo anschauen, wieso immer noch die gleiche Zahl drin steht...
      rewardsController.text = (rewardsThresholdValue != null && rewardsNotificationsEnabled==true) ? rewardsThresholdValue.toString() : "";
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return CustomDialog(
              title: 'Notification Settings',
              content: DefaultTabController(
                length: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TabBar(
                      labelColor: Colors.tealAccent,
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: Colors.tealAccent,
                      tabs: [
                        Tab(text: 'Settings'),
                        Tab(text: 'Control'),
                      ],
                      onTap: (index) async {
                        if (index == 1) {
                          await fetchAndUpdateUserAddresses(setState);
                          // Call dialog's state update to refresh UI
                          setState(() {});
                        }
                      },
                    ),
                    SizedBox(height: 10),
                    Container(
                      height: screenHeight * 0.25, // Set a fixed height for the TabBarView
                      child: TabBarView(
                        children: [
                          // First tab content (Settings)
                          SingleChildScrollView(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: rewardsNotificationsEnabled,
                                      activeColor: Colors.tealAccent,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          rewardsNotificationsEnabled = value!;
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Enable Rewards Notification',
                                            style: TextStyle(
                                              color: const Color(0xFFdbd7fb),
                                              fontSize: 16.0,
                                            ),
                                          ),
                                          SizedBox(height: 4.0),
                                          Text(
                                            'You will receive notifications when your reward threshold is met.',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: validatorNotificationsEnabled,
                                      activeColor: Colors.tealAccent,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          validatorNotificationsEnabled = value!;
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Enable Validator Notification',
                                            style: TextStyle(
                                              color: const Color(0xFFdbd7fb),
                                              fontSize: 16.0,
                                            ),
                                          ),
                                          SizedBox(height: 4.0),
                                          Text(
                                            'You will be notified when one of your staked validators becomes unelected.',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                TextField(
                                  controller: rewardsController,
                                  enabled: rewardsNotificationsEnabled,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: const Color(0xFFdbd7fb)),
                                  decoration: InputDecoration(
                                    hintText: "Enter reward threshold...",
                                    hintStyle: TextStyle(color: Colors.grey[600]),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.tealAccent),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.tealAccent),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Second tab content (Control)
                          SingleChildScrollView(
                            child: Column(
                              children: userAddresses.map((addressData) {
                                address = addressData['address'];
                                validatorEnabled = addressData['validatorEnabled'] ?? false;
                                rewardsEnabled = addressData['rewardsEnabled'] ?? false;
                                double rewardsthresholdCard = addressData['rewardsThreshold'];
                                TextEditingController rewardsControllerCardTest = TextEditingController();
                                rewardsControllerCardTest.text = rewardsthresholdCard.toString();
                                // Modified part inside the userAddresses.map(...) function
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                                  child: Container(
                                    width: MediaQuery.of(context).size.width * 0.9, // Set a specific width for the container
                                    child: Card(
                                      color: Colors.transparent, // Make the card itself transparent
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      elevation: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.2), // Semi-transparent grey background
                                          borderRadius: BorderRadius.circular(15), // Keep the card's rounded corners
                                        ),
                                        padding: EdgeInsets.all(5.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              shortAddress(address),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4.0),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Validator Notification Switch
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Validator',
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                    Switch(
                                                      value: validatorEnabled,
                                                      onChanged: (bool value) {
                                                        setState(() {
                                                          addressData['validatorEnabled'] = value;
                                                          // Update the validator notification settings
                                                        });
                                                      },
                                                      activeColor: Colors.tealAccent,
                                                      inactiveThumbColor: Colors.grey,
                                                      inactiveTrackColor: Colors.grey[700],
                                                    ),
                                                  ],
                                                ),
                                                // Rewards Notification Switch
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Rewards',
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                    Switch(
                                                      value: rewardsEnabled,
                                                      onChanged: (bool value) {
                                                        setState(() {
                                                          addressData['rewardsEnabled'] = value;
                                                          // Update the rewards notification settings
                                                        });
                                                      },
                                                      activeColor: Colors.tealAccent,
                                                      inactiveThumbColor: Colors.grey,
                                                      inactiveTrackColor: Colors.grey[700],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 1.0),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    onChanged: (text) {
                                                      addressData['rewardsThreshold'] = double.tryParse(rewardsControllerCardTest.text);
                                                      rewardsControllerCardTest.text = text;
                                                    },
                                                    controller: rewardsControllerCardTest,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.tealAccent),
                                                    decoration: InputDecoration(
                                                      hintText: "Enter reward threshold...",
                                                      hintStyle: TextStyle(color: Colors.grey[600]),
                                                      enabledBorder: UnderlineInputBorder(
                                                        borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.1)),
                                                      ),
                                                      focusedBorder: UnderlineInputBorder(
                                                        borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.0)),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.save, color: Colors.tealAccent, shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 10.0)]),
                                                  onPressed: () async {
                                                    double? newThreshold = double.tryParse(rewardsControllerCardTest.text);
                                                    if (newThreshold != null) {
                                                      updateWalletAlerts(addressData['address'], newThreshold, !addressData['rewardsEnabled'], !addressData['validatorEnabled']);
                                                      if (addressData['address'] == address_label) {
                                                        setState(() {
                                                          validatorNotificationsEnabled = addressData['validatorEnabled'];
                                                          rewardsNotificationsEnabled = addressData['rewardsEnabled'];
                                                          rewardThreshold = newThreshold;
                                                          _saveRewardsTrigger(newThreshold);
                                                          rewardsController.text = rewardThreshold.toString();
                                                        });
                                                      }
                                                      toastification.show(
                                                        context: context,
                                                        style: ToastificationStyle.fillColored,
                                                        type: ToastificationType.success,
                                                        title: Text('Rewards threshold updated successfully'),
                                                        autoCloseDuration: const Duration(seconds: 5),
                                                      );
                                                    } else {
                                                      toastification.show(
                                                        context: context,
                                                        style: ToastificationStyle.fillColored,
                                                        type: ToastificationType.error,
                                                        title: Text('Please enter a valid number for the threshold'),
                                                        autoCloseDuration: const Duration(seconds: 5),
                                                      );
                                                    }
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.delete, color: Colors.redAccent, shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 10.0)]),
                                                  onPressed: () async {
                                                    await deleteAddressFromDB(username, addressData['address']);
                                                    setState(() {
                                                      userAddresses.removeWhere((item) => item['address'] == addressData['address']);
                                                    });
                                                    toastification.show(
                                                      context: context,
                                                      style: ToastificationStyle.fillColored,
                                                      type: ToastificationType.success,
                                                      title: Text('Alert deleted successfully'),
                                                      autoCloseDuration: const Duration(seconds: 5),
                                                    );
                                                    if (addressData['address'] == address_label) {
                                                      setState(() {
                                                        validatorNotificationsEnabled = false;
                                                        rewardsNotificationsEnabled = false;
                                                        _deleteRewardsTrigger();
                                                        rewardsController.text = "";
                                                      });
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          child: Text(
                            'Close',
                            style: TextStyle(color: Colors.tealAccent),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text(
                            'Save',
                            style: TextStyle(color: Colors.tealAccent),
                          ),
                          onPressed: () async {
                            if (rewardsNotificationsEnabled! &&
                                validatorNotificationsEnabled!) {
                              setValidatorNotification = false;
                              setRewardsNotification = false;
                              rewardThreshold =
                                  double.tryParse(rewardsController.text);
                              if (rewardThreshold != null) {
                                saveUserFCMTokenRewardstriggerValidatorAlertToDatabase(
                                    address_label, rewardThreshold!);
                                _saveRewardsTrigger(rewardThreshold!);
                                setState(() {
                                  alertOpacity = 1.0;
                                  _getAccountInfo();
                                });
                                toastification.show(
                                  context: context,
                                  style: ToastificationStyle.fillColored,
                                  type: ToastificationType.success,
                                  title: Text(
                                      'You will be notified when your Rewards Threshold has reached $rewardThreshold ONE \n and if one of your validators is not elected anymore'),
                                  autoCloseDuration: const Duration(seconds: 5),
                                );
                              } else {
                                toastification.show(
                                  context: context,
                                  style: ToastificationStyle.fillColored,
                                  type: ToastificationType.error,
                                  title: Text('Invalid or no number entered.'),
                                  autoCloseDuration: const Duration(seconds: 5),
                                );
                              }
                            } else if (rewardsNotificationsEnabled! &&
                                !validatorNotificationsEnabled!) {
                              setValidatorNotification = true;
                              setRewardsNotification = false;
                              rewardThreshold =
                                  double.tryParse(rewardsController.text);
                              if (rewardThreshold != null) {
                                saveUserFCMTokenRewardstriggerValidatorAlertToDatabase(
                                    address_label, rewardThreshold!);
                                _saveRewardsTrigger(rewardThreshold!);
                                setState(() {
                                  alertOpacity = 1.0;
                                  _getAccountInfo();
                                });
                                toastification.show(
                                  context: context,
                                  style: ToastificationStyle.fillColored,
                                  type: ToastificationType.success,
                                  title: Text(
                                      'You will be notified when your Rewards Threshold has reached $rewardThreshold ONE'),
                                  autoCloseDuration: const Duration(seconds: 5),
                                );
                              } else {
                                toastification.show(
                                  context: context,
                                  style: ToastificationStyle.fillColored,
                                  type: ToastificationType.error,
                                  title: Text('Invalid number entered.'),
                                  autoCloseDuration: const Duration(seconds: 5),
                                );
                              }
                            } else if (!rewardsNotificationsEnabled! &&
                                validatorNotificationsEnabled!) {
                              setValidatorNotification = false;
                              setRewardsNotification = true;
                              await _deleteRewardsTrigger();
                              saveUserFCMTokenRewardstriggerValidatorAlertToDatabase(
                                  address_label, rewardThreshold!);
                              toastification.show(
                                context: context,
                                style: ToastificationStyle.fillColored,
                                type: ToastificationType.success,
                                title: Text(
                                    'You will be notified if one of your validators is not elected anymore'),
                                autoCloseDuration: const Duration(seconds: 5),
                              );
                            } else {
                              if (username.isNotEmpty) {
                                await _deleteRewardsTrigger();
                                setValidatorNotification = true;
                                setRewardsNotification = true;
                                setState(() {
                                  alertOpacity = 0.0;
                                  _getAccountInfo();
                                });
                                saveUserFCMTokenRewardstriggerValidatorAlertToDatabase(
                                    address_label, rewardThreshold!);
                                Navigator.of(context).pop();
                                toastification.show(
                                  context: context,
                                  style: ToastificationStyle.fillColored,
                                  type: ToastificationType.success,
                                  title: Text(
                                      'All notifications are now disabled'),
                                  autoCloseDuration: const Duration(seconds: 5),
                                );
                              } else {
                                toastification.show(
                                  context: context,
                                  style: ToastificationStyle.fillColored,
                                  type: ToastificationType.info,
                                  title: Text(
                                      'Enable any notification before saving'),
                                  autoCloseDuration: const Duration(seconds: 5),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  //Todo testen und in _getAccountInfo einbauen
  Future<Map<String, dynamic>?> fetchUserDetailsByFcmToken(String fcmToken) async {
    final String apiUrl = 'https://europe-west1-harmonyrewards.cloudfunctions.net/api/getUserDetailsByFcmToken/$fcmToken';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return {
          'uid': responseData['uid'],
          'data': responseData['data'],
        };
      } else if (response.statusCode == 404) {
        print('User not found for the provided FCM token.');
        return null;
      } else {
        print('Failed to fetch user details: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calling the API: $e');
      return null;
    }
  }
//Todo Kann in der Zukunft verwendet werden, falls ein Account erstellt werden möchte.
  void loadUserData(String fcmToken) async {
    Map<String, dynamic>? userDetails = await fetchUserDetailsByFcmToken(fcmToken);

    if (userDetails != null) {
      String uid = userDetails['uid'];
      Map<String, dynamic> data = userDetails['data'];

      List<String> addressListHistory = List<String>.from(data['addressListHistory'] ?? []);
      Map<String, Map<String, dynamic>> favoriteAddressMap = Map<String, Map<String, dynamic>>.from(
          data['favoriteAddressMap'] ?? {}
      );
      String currentAddress = data['currentAddress'] ?? '';
      username = uid;
      address_label = currentAddress;
     // loading = true;
      _getAccountInfo();


      print('UID: $uid');
      print('Current Address: $currentAddress');
      print('Address List History: $addressListHistory');
      print('Favorite Address Map: $favoriteAddressMap');

      // Update your app's state with this data
    } else {
      print('No user data found or an error occurred.');
    }
  }

  void showFavouriteListDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get the screen height
        double screenHeight = MediaQuery.of(context).size.height;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.transparent, // Transparent background
              content: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    // Set the height dynamically as a fraction of the screen height
                    width: double.maxFinite,
                    alignment: Alignment.center,
                    height: screenHeight * 0.5,
                    // 40% of the screen height
                    margin: EdgeInsets.only(top: 34),
                    decoration: BoxDecoration(
                      color: Color(0xFF1D1E33), // Dark background color
                      borderRadius:
                          BorderRadius.circular(20.0), // Rounded corners
                    ),
                    padding: EdgeInsets.all(15.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Headline
                        Text(
                          'Favorite Addresses',
                          style: TextStyle(
                            color: const Color(0xFFdbd7fb),
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20.0),
                        // Space between headline and list

                        // List of favorite addresses
                        Expanded(
                          child: favoriteAddressMap.value.isNotEmpty
                              ? ListView.separated(
                                  itemCount: favoriteAddressMap.value.length,
                                  separatorBuilder:
                                      (BuildContext context, int index) {
                                    return Divider(
                                      color: const Color(0xFFdbd7fb),
                                      // Color of the separator
                                      thickness:
                                          1.0, // Thickness of the separator
                                    );
                                  },
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    String address = favoriteAddressMap.value.keys
                                        .elementAt(index);
                                    String label = favoriteAddressMap.value[address]
                                            ?['label'] ??
                                        "No Label";
                                    bool isFavorite =
                                        favoriteAddressMap.value[address]
                                                ?['isFavorite'] ??
                                            false;

                                    return Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.grey.withOpacity(0.2),
                                      ),
                                      child: ListTile(
                                        iconColor: Colors.amber,
                                        textColor: const Color(0xFFdbd7fb),
                                        title: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Display the label and address
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${index + 1}. $label',
                                                  style: TextStyle(
                                                    color:
                                                        const Color(0xFFdbd7fb),
                                                    fontSize: 16.0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 4.0),
                                                Text(
                                                  shortAddress(address),
                                                  style: TextStyle(
                                                    color: Colors.tealAccent,
                                                    fontSize: 14.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Heart icon for removing from favorites
                                            IconButton(
                                              icon: Icon(
                                                isFavorite
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: isFavorite
                                                    ? Color(0xFF39D2C0)
                                                    : const Color(0xFFdbd7fb),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  favoriteAddressMap.value
                                                      .remove(address);
                                                  //favoriteAddressMap.notifyListeners();
                                                });
                                                _saveFavoriteAddresses();
                                              },
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          // Handle the item selection here
                                          address_label = address;
                                          setState(() {
                                            newAddress = true;
                                            alertOpacity = 0.0;
                                            //loading = true;
                                            _getAccountInfo();
                                          });
                                          Navigator.of(context)
                                              .pop(); // Close the dialog*/
                                        },
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    "No favorite addresses available",
                                    style: TextStyle(
                                      color: const Color(0xFFdbd7fb),
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                        ),
                        SizedBox(height: 20.0),
                        // Space between the list and the button
                        // Clear and Cancel buttons

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          // Align buttons to the right
                          children: [
                            TextButton(
                              onPressed: () {
                                _deleteFavoriteList(setState);
                              },
                              child: Text(
                                'Clear List',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  // Color of the clear button
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                showInputAddAddresstoFav();
                              },
                              child: Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  // Color of the clear button
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pop(); // Close the dialog when cancel is pressed
                              },
                              child: Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  // Color of the cancel button
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void showAddressHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get the screen height
        double screenHeight = MediaQuery.of(context).size.height;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.transparent, // Transparent background
              content: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    // Set the height dynamically as a fraction of the screen height
                    width: double.maxFinite,
                    alignment: Alignment.center,
                    height: screenHeight * 0.4,
                    // 40% of the screen height
                    margin: EdgeInsets.only(top: 34),
                    decoration: BoxDecoration(
                      color: Color(0xFF1D1E33), // Dark background color
                      borderRadius:
                          BorderRadius.circular(20.0), // Rounded corners
                    ),
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Headline
                        Text(
                          'Last Used Addresses',
                          style: TextStyle(
                            color: const Color(0xFFdbd7fb),
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20.0),
                        // Space between headline and list

                        // List of items
                        Expanded(
                          child: addressListHistory.value.isNotEmpty
                              ? ListView.separated(
                                  itemCount: addressListHistory.value.length,
                                  separatorBuilder:
                                      (BuildContext context, int index) {
                                    return Divider(
                                      color: const Color(0xFFdbd7fb),
                                      // Color of the separator
                                      thickness:
                                          1.0, // Thickness of the separator
                                    );
                                  },
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    String address = addressListHistory.value[index];
                                    bool isFavorite =
                                        favoriteAddressMap.value.containsKey(address);
                                    return GestureDetector(
                                      onTap: () {
                                        // Handle the item selection here
                                        address_label =
                                          addressListHistory.value[index];
                                        setState(() {
                                          newAddress = true;
                                          alertOpacity = 0.0;
                                          //loading = true;
                                          _getAccountInfo();
                                        });
                                        Navigator.of(context)
                                            .pop(); // Close the dialog
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(10.0),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: Colors.grey.withOpacity(0.2),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Address display
                                            Center(
                                              child: Text(
                                                shortAddress(address),
                                                style: TextStyle(
                                                  color: Colors.tealAccent,
                                                  fontSize: 14.0,
                                                ),
                                              ),
                                            ),
                                            // Heart icon
                                            IconButton(
                                              icon: Icon(
                                                isFavorite
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: isFavorite
                                                    ? Color(0xFF39D2C0)
                                                    : const Color(0xFFdbd7fb),
                                              ),
                                              onPressed: () async {
                                                if (isFavorite) {
                                                  // Remove from favorites
                                                  setState(() {
                                                    favoriteAddressMap.value
                                                        .remove(address);
                                                    //favoriteAddressMap.notifyListeners();
                                                  });
                                                  _saveFavoriteAddresses();
                                                } else {
                                                  // Add to favorites
                                                  String? label =
                                                      await _promptForLabel(
                                                          context);
                                                  if (label != null &&
                                                      label.isNotEmpty) {
                                                    setState(() {
                                                      favoriteAddressMap.value[
                                                          address] = {
                                                        "label": label,
                                                        "isFavorite": true
                                                      };
                                                      //favoriteAddressMap.notifyListeners();
                                                    });
                                                    _saveFavoriteAddresses();
                                                    toastification.show(
                                                      context: context,
                                                      style: ToastificationStyle
                                                          .fillColored,
                                                      type: ToastificationType
                                                          .success,
                                                      title: Text(
                                                          'The wallet $label has been added to your favorites.'),
                                                      autoCloseDuration:
                                                          const Duration(
                                                              seconds: 5),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    "No addresses available",
                                    style: TextStyle(
                                      color: const Color(0xFFdbd7fb),
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                        ),
                        SizedBox(height: 20.0),
                        // Space between the list and the button

                        // Clear and Cancel buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                _deleteAddressList(
                                    setState); // Pass setState to update the dialog
                              },
                              child: Text(
                                'Clear List',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  // Color of the clear button
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pop(); // Close the dialog when cancel is pressed
                              },
                              child: Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  // Color of the cancel button
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _promptForLabel(BuildContext context) async {
    TextEditingController _labelController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.transparent, // Transparent background
              content: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 24),
                    decoration: BoxDecoration(
                      color: Color(0xFF1D1E33), // Dark background color
                      borderRadius:
                          BorderRadius.circular(20.0), // Rounded corners
                    ),
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter Wallet Label',
                          style: TextStyle(
                            color: const Color(0xFFdbd7fb),
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _labelController,
                          style: TextStyle(color: const Color(0xFFdbd7fb)),
                          decoration: InputDecoration(
                            hintText: "Enter label for the wallet",
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.tealAccent),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.tealAccent),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pop(null); // Cancel action
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pop(_labelController.text); // Return label
                              },
                              child: Text(
                                'OK',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> checkValidatorNotificationSent() async {
    try {
      if (username.isNotEmpty) {
        // Reference to the user's data in the database
        DatabaseReference databaseReference = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: databaseURL,
        ).ref('users/$username');

        // Get the data snapshot for the user
        DataSnapshot snapshot =
            await databaseReference.child('notificationSentForValidator').get();

        // Check if the snapshot exists and retrieve the value
        if (snapshot.exists) {
          bool? notificationSent = snapshot.value as bool?;
          return notificationSent;
        } else {
          print(
              'User does not exist or notificationSentForValidator field not found');
          return null;
        }
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
    return null;
  }

  Future<double?> getRewardsThreshold(String uid, String address) async {
    final String apiUrl = 'https://europe-west1-harmonyrewards.cloudfunctions.net/api/getRewardsThreshold/$uid/$address';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        // Parse the response body
        final responseData = json.decode(response.body);
        final rewardsThreshold = responseData['rewardsThreshold'];

        // Convert to double and return
        return rewardsThreshold is double ? rewardsThreshold : double.tryParse(rewardsThreshold.toString());
      } else {
        print('Failed to get rewards threshold. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching rewards threshold: $e');
      return null;
    }
  }


  Future<List<String>> getUserAddresses(String uid) async {
    final String apiUrl =
        'https://europe-west1-harmonyrewards.cloudfunctions.net/api/getUserAddresses/$uid'; // Replace with your backend URL

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<String> addresses = List<String>.from(responseData['addresses']);
        return addresses;
      } else {
        print("Failed to retrieve addresses: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching user addresses: $e");
      return [];
    }
  }






  Future<bool?> checkNotificationsfromDB(
      String uid, String address, String ValorRew) async {
    final String apiUrl =
        'https://europe-west1-harmonyrewards.cloudfunctions.net/api/getUserData/$uid/$address'; // Replace with your backend URL
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        if (ValorRew.contains("Rewards")) {
          final responseData = json.decode(response.body);
          if (responseData['notificationSentStatus'] == 'true') {
            return true;
          }
          return false;
        } else if (ValorRew.contains("Validator")) {
          final responseData = json.decode(response.body);
          if (responseData['notificationSentForValidatorStatus'] == 'true') {
            return true;
          }
          return false;
        }
      } else {
        return true;
      }
    } catch (e) {
      print("Fehler beim UserCheck");
      return true;
    }
  }



  @override
  void initState() {
    super.initState();


    //subscription  = Connectivity().onConnectivityChanged.listen(_checkInternetConnection as void Function(List<ConnectivityResult> event)?);
    _getEpochsUntilUndelegation();
    // Listen for foreground messages
    // Initialize Firebase Messaging and handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received a message while in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
      _deleteRewardsTrigger();
      setState(() {
        alertOpacity = 0.0;
        _deleteRewardsTrigger();
        //loading = true;
      });
      // saveUserFCMTokenRewardstriggerValidatorAlertToDatabase(address_label, rewardThreshold!);
      _getAccountInfo();
      // Toggle the flag when a message is received
    });

    WidgetsBinding.instance.addObserver(this); // Start observing app lifecycle
    _startPeriodicTask(); // Start task initially when app is launched

    _loadlastAddresses();
    loadFavoriteAddresses();
    _loadSavedText();
    _loadSavedUsername();

    _loadRewardsTrigger();
    _model = createModel(context, () => HomeModel());

    // Shake Animation
    animationsMap.addAll({
      'textOnPageLoadAnimation': AnimationInfo(
        loop: true,
        reverse: true,
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          ShimmerEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 1520.0.ms,
            color: Color(0x80FFFFFF),
            angle: 0.524,
          ),
        ],
      ),
      'containerOnActionTriggerAnimation': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: true,
        effectsBuilder: () => [
          ShimmerEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 1000.0.ms,
            color: Color(0x80FFFFFF),
            angle: 0.524,
          ),
        ],
      ),
    });

    setupAnimations(
      animationsMap.values.where((anim) =>
          anim.trigger == AnimationTrigger.onActionTrigger ||
          !anim.applyInitialState),
      this,
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      final animation = animationsMap['containerOnPageLoadAnimation5'];
      if (animation != null) {
        animation.controller.forward(from: 0.0);
      }
    });

    animationsMap_loop.addAll({
      'textOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          ShakeEffect(
            curve: Curves.elasticOut,
            delay: 1520.0.ms,
            duration: 1000.0.ms,
            hz: 10,
            offset: Offset(0.0, 0.0),
            rotation: 0.087,
          ),
        ],
      ),
    });
  }



  Future<void> saveOrUpdateUserDetails() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      // Extract values from the ValueNotifiers before encoding
      List<String> addressHistory = addressListHistory.value;
      Map<String, dynamic> favoriteAddresses = favoriteAddressMap.value;

      // Convert favoriteAddresses to a format that can be JSON encoded
      Map<String, dynamic> favoriteAddressesJson = favoriteAddresses.map((key, value) =>
          MapEntry(key, value)
      );

      // Create the body to be sent in the POST request
      Map<String, dynamic> requestBody = {
        'uid': username, // Replace 'username' with the appropriate user ID
        'currentAddress': address_label,
        'addressListHistory': addressHistory,
        'favoriteAddressMap': favoriteAddressesJson,
        'fcmToken': fcmToken,
      };

      final response = await http.post(
        Uri.parse('https://europe-west1-harmonyrewards.cloudfunctions.net/api/saveOrUpdateUserDetails'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print('User details saved/updated successfully.');
      } else {
        print('Failed to save/update user details: ${response.body}');
      }
    } catch (error) {
      print('Error saving/updating user details: $error');
    }
  }


  void _startPeriodicTask() {
    if (_timer == null) {
      _timer = Timer.periodic(Duration(seconds: 30), (timer)async {
        if(myDelegatorList.isNotEmpty) {
          _getAccountInfo();
        }
      });
      print("Periodic task started.");
    }
  }




  void _checkInternetConnection(ConnectivityResult connectivityResult)  {
    if (connectivityResult == ConnectivityResult.mobile) {
      // The app is connected to a mobile network.
    } else if (connectivityResult == ConnectivityResult.wifi) {
      // The app is connected to a WiFi network.
    } else if (connectivityResult == ConnectivityResult.other) {
      // The app is connected to a network that is not in the above mentioned networks.
    } else if (connectivityResult == ConnectivityResult.none) {
      // The app is not connected to any network.
    }
  }



  void _stopPeriodicTask() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      print("Periodic task stopped.");
    }
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App has come to the foreground
      _startPeriodicTask();
      loadAlertIcon();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // App is minimized, backgrounded, or closed
      _stopPeriodicTask();
    }
  }

  @override
  void dispose() {
    _model.dispose();
    _stopPeriodicTask(); // Stop the task when the widget is disposed
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }


  Future<void> fetchAndUpdateUserAddresses(StateSetter setState) async {
    if (username.isNotEmpty) {
      List<String> addresses = await getUserAddresses(username);

      List<Future<Map<String, dynamic>>> notificationFutures = addresses.map((address) async {
        bool? isValidatorEnabled = await checkNotificationsfromDB(username, address, "Validator");
        bool? isRewardsEnabled = await checkNotificationsfromDB(username, address, "Rewards");
        double? rewardsThresholdValue = await getRewardsThreshold(username, address);
        return {
          'address': address,
          'validatorEnabled': !isValidatorEnabled!,
          'rewardsEnabled': !isRewardsEnabled!,
          'rewardsThreshold': rewardsThresholdValue,
        };
      }).toList();

      // Run all the futures concurrently and wait for them to complete
      List<Map<String, dynamic>> updatedUserAddresses = await Future.wait(notificationFutures);
      setState(() {
        userAddresses = updatedUserAddresses; // Update the list in the state
      });
    }
  }
  Future<void> sendUserData({
    required String uid,
    required String fcmToken,
    required String address,
    required double rewardsTrigger,
    required bool setRewardsNotification,
    required bool setValidatorNotification,
  }) async {
    // Prepare the list of delegations in the required format
    List<Map<String, String>> delegations = myDelegatorList
        .map((validatorAddress) => {'validatorAddress': validatorAddress})
        .toList();

    // Construct the request body
    Map<String, dynamic> requestBody = {
      'uid': uid,
      'fcmToken': fcmToken,
      'address': address,
      'rewardsTrigger': rewardsTrigger,
      'notificationSent': setRewardsNotification,
      'notificationSentForValidator': setValidatorNotification,
      'delegations': delegations,
    };
    // Define the API endpoint for saving user data
    String apiUrl =
        'https://europe-west1-harmonyrewards.cloudfunctions.net/api/saveUserData';
    try {
      // Make the POST request to the web service
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody), // Convert the request body to JSON
      );

      if (response.statusCode == 200) {
        print('User data saved successfully');
      } else {
        print('Failed to save user data: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (error) {
      print('Error sending user data: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? Stack(
            children: [
              // This is the transparent background
              Container(
                color: Colors.black.withOpacity(
                    0.5), // Optional: add a slight transparency for overlay effect
              ),
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        Colors.grey[200], // Light grey background for the box
                    borderRadius: BorderRadius.circular(15), // Rounded corners
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Fetching Data, please wait.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 20), // Space between text and indicator
                      CircularProgressIndicator(
                        semanticsLabel: 'Circular progress indicator',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : GestureDetector(
            onTap: () => _model.unfocusNode.canRequestFocus
                ? FocusScope.of(context).requestFocus(_model.unfocusNode)
                : FocusScope.of(context).unfocus(),
            child: Scaffold(
              key: scaffoldKey,
              // Assign the GlobalKey to Scaffold
              backgroundColor: Color(0xFF150925),
              // Add SidebarX Drawer
              drawer: SidebarX(
                controller: _controller,
                theme: SidebarXTheme(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF210e3a), // Background color of sidebar
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(0.0),
                        bottomRight: Radius.circular(26.0),
                        topLeft: Radius.circular(0.0),
                        topRight: Radius.circular(26.0)),
                  ),
                  textStyle: TextStyle(
                    color: const Color(0xFFdbd7fb),
                    fontSize: 16.0,
                  ),
                  iconTheme: IconThemeData(
                    color: const Color(0xFFdbd7fb),
                  ),
                  selectedIconTheme: IconThemeData(
                    color: Color(0xFF39D2C0), // Icon color for selected items
                  ),
                  selectedTextStyle: TextStyle(
                    color: Color(0xFF39D2C0), // Text color for selected items
                    fontSize: 16.0,
                  ),
                  itemTextPadding: EdgeInsets.only(left: 20),
                  selectedItemTextPadding: EdgeInsets.only(left: 20),
                  selectedItemDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.tealAccent
                        .withOpacity(0.3), // Selected item background
                  ),
                ),
                extendedTheme: SidebarXTheme(
                  width: 220, // Width of the extended sidebar to show text
                ),
                headerBuilder: (context, extended) {
                  return Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(16.0, 50.0, 16.0, 50.0),
                    child: Container(
                      height: 120.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4B39EF), Color(0xFFEE8B60)],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(1.0, -1.0),
                          end: AlignmentDirectional(-1.0, 1.0),
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Container(
                            width: 140.0,
                            height: 140.0,
                            decoration: BoxDecoration(
                              color: Color(0xFF24103F),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(2.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.0),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                items: [
                  SidebarXItem(
                    icon: Icons.create_outlined,
                    label: 'Add/Edit Address', // Text for the item
                    onTap: () {
                      showInput();
                    },
                  ), //Add/Edit Address
                  SidebarXItem(
                    icon: Icons.favorite_outlined,
                    label: 'Favorite Addresses', // Text for the item
                    onTap: () {
                      showFavouriteListDialog();
                    },
                  ), //Fav. Address
                  SidebarXItem(
                    icon: Icons.list_alt,
                    label: 'Address History', // Text for the item
                    onTap: () {
                      showAddressHistoryDialog();
                    },
                  ), // Address History
                  SidebarXItem(
                    icon: Icons.safety_divider_rounded,
                    label: 'My Validators', // Text for the item
                    onTap: () {
                      showDelegationsDialog(context, address_label, myDelegatorList);
                    },
                  ),
                  SidebarXItem(
                    icon: Icons.circle_notifications_outlined,
                    label: 'Alerts', // Text for the item
                    onTap: () {
                      if (address_label
                          .contains("-> Insert your Wallet Address <-")) {
                        toastification.show(
                          context: context,
                          style: ToastificationStyle.fillColored,
                          type: ToastificationType.info,
                          title: Text(
                              'Put in your wallet address before creating an alert.'),
                          autoCloseDuration: const Duration(seconds: 7),
                        );
                        showInput();
                      } else {
                        showNotificationSettingsDialog();
                      }
                    },
                  ), //Alerts
                  SidebarXItem(
                    icon: Icons.refresh,
                    label: 'Refresh', // Text for the item
                    onTap: () {
                      if (!address_label
                          .contains("-> Insert your Wallet Address <-")) {
                        setState(() {
                          //loading = true;
                          _getAccountInfo();
                        });
                      } else {
                        toastification.show(
                          context: context,
                          style: ToastificationStyle.fillColored,
                          type: ToastificationType.error,
                          title: Text(
                              'Nothing to refresh. Put in your wallet address first.'),
                          autoCloseDuration: const Duration(seconds: 7),
                        );
                      }
                    },
                  ), //Refresh
                  SidebarXItem(
                    icon: Icons.help_outline,
                    label: 'Help', // Text for the item
                    onTap: () {
                      // Functionality to reset app
                    },
                  ), //Help
                  SidebarXItem(
                    icon: Icons.restart_alt,
                    label: 'Reset App', // Text for the item
                    onTap: () {
                      resetData();
                    },
                  ), //Reset the app data
                ],
              ),
              appBar: PreferredSize(
                preferredSize:
                    ui.Size.fromHeight(50), // Increase the app bar height
                child: Padding(
                  padding:
                      EdgeInsets.only(top: 0.0), // Pushes the AppBar downwards
                  child: AppBar(
                    elevation: 2, // Remove AppBar shadow
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Empty container to take space on the left side, balancing the Row
                        Container(),
                        Text(
                          'ONETracker',
                          style:
                              FlutterFlowTheme.of(context).labelMedium.override(
                                    fontFamily: 'Plus Jakarta Sans',
                                    color: Color(0xFFdbd7fb),
                                    fontSize: 18.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    backgroundColor: Color(0xFF150925),
                    leading: Padding(
                      padding:
                          EdgeInsets.only(left: 0.0), // Push the button right
                      child: IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: Color(0xFFdbd7fb),
                          size: 40,
                        ), // Sidebar toggle button

                        onPressed: () {
                          scaffoldKey.currentState
                              ?.openDrawer(); // Open the sidebar when pressed
                        },
                      ),
                    ),
                  ),
                ),
              ),
              body: Align(
                alignment: AlignmentDirectional(0.0, 0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            child: Container(
                              width: 90.0,
                              height: 90.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF4B39EF),
                                    Color(0xFFEE8B60)
                                  ],
                                  stops: [0.0, 1.0],
                                  begin: AlignmentDirectional(1.0, -1.0),
                                  end: AlignmentDirectional(-1.0, 1.0),
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsets.all(2.0),
                                  child: Container(
                                    width: 80.0,
                                    height: 80.0,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF24103F),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          width: 100.0,
                                          height: 100.0,
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(16.0, 10.0, 16.0, 0.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Show the label only if the address is a favorite
                          if (favoriteAddressMap.value.containsKey(address_label) &&
                              favoriteAddressMap.value[address_label]![
                                      'isFavorite'] ==
                                  true)
                            Padding(
                              padding: EdgeInsets.only(bottom: 2.0),
                              // Space between label and address
                              child: Text(
                                favoriteAddressMap.value[address_label]!['label'],
                                // Show the label here
                                style: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      fontFamily: 'Plus Jakarta Sans',
                                      color: Color(0xFFdbd7fb),
                                      // You can customize the color
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  showInput();
                                },
                                child: GradientText(
                                  shortAddress(address_label),
                                  style: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(
                                        fontFamily: 'Plus Jakarta Sans',
                                        color: Color(0xFF39D2C0),
                                        fontSize: 18.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                  colors: [
                                    Color(0xFF4B39EF),
                                    Color(0xFFEE8B60)
                                  ],
                                  gradientDirection: GradientDirection.ltr,
                                  gradientType: GradientType.linear,
                                ),
                              ).animateOnPageLoad(
                                  animationsMap['textOnPageLoadAnimation']!),
                              if (!address_label
                                  .contains("Insert")) // Condition to hide icon
                                IconButton(
                                  icon: Icon(
                                    favoriteAddressMap.value
                                                .containsKey(address_label) &&
                                            favoriteAddressMap.value[address_label]![
                                                    'isFavorite'] ==
                                                true
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: favoriteAddressMap.value
                                                .containsKey(address_label) &&
                                            favoriteAddressMap.value[address_label]![
                                                    'isFavorite'] ==
                                                true
                                        ? Color(0xFF39D2C0)
                                        : Color(
                                            0xFFdbd7fb), // Green for favorite, grey otherwise
                                  ),
                                  onPressed: () async {
                                    if (favoriteAddressMap.value
                                            .containsKey(address_label) &&
                                        favoriteAddressMap.value[address_label]![
                                                'isFavorite'] ==
                                            true) {
                                      // Remove from favorites
                                      setState(() {
                                        favoriteAddressMap.value
                                            .remove(address_label);
                                       // favoriteAddressMap.notifyListeners();
                                      });
                                      _saveFavoriteAddresses();
                                    } else {
                                      // Add to favorites
                                      String? label =
                                          await _promptForLabel(context);
                                      if (label != null && label.isNotEmpty) {
                                        setState(() {
                                          favoriteAddressMap.value[address_label] = {
                                            "label": label,
                                            "isFavorite": true
                                          };
                                          //favoriteAddressMap.notifyListeners();
                                        });
                                        _saveFavoriteAddresses();
                                        toastification.show(
                                          context: context,
                                          style:
                                              ToastificationStyle.fillColored,
                                          type: ToastificationType.success,
                                          title: Text(
                                              'The wallet $label has been added to your favorites.'),
                                          autoCloseDuration:
                                              const Duration(seconds: 5),
                                        );
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ).animateOnPageLoad(
                        animationsMap_loop['textOnPageLoadAnimation']!),
                    Divider(
                      thickness: 1.0,
                      color: Color(0x4FFFFFFF),
                    ),

                    if (undelegationepoch != 0)
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 0.0, 0.0),
                        child: AutoSizeText(
                          epochsToUndelegat == 0
                              ? 'Pending undelegations of $undelegationAmount \$ONE: end of current epoch'
                              : 'Pending undelegations of $undelegationAmount \$ONE in $epochsToUndelegat Epochs',
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 16.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(0.0),
                            bottomRight: Radius.circular(0.0),
                            topLeft: Radius.circular(16.0),
                            topRight: Radius.circular(16.0),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(0.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Align(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 16.0, 0.0, 0.0),
                                          child: Wrap(
                                            spacing: 16.0,
                                            runSpacing: 16.0,
                                            alignment: WrapAlignment.start,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.start,
                                            direction: Axis.horizontal,
                                            runAlignment: WrapAlignment.start,
                                            verticalDirection:
                                                VerticalDirection.down,
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.40,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height *
                                                        0.185,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .accent1,
                                                      Color(0xFF414F57)
                                                    ],
                                                    stops: [0.0, 1.0],
                                                    begin: AlignmentDirectional(
                                                        0.0, -1.0),
                                                    end: AlignmentDirectional(
                                                        0, 1.0),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          24.0),
                                                ),
                                                child: Padding(
                                                  padding: EdgeInsets.all(12.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  -1.0, 0.0),
                                                        ),
                                                      ),
                                                      Image.asset(
                                                        'assets/images/piggy-bank.png',
                                                        width: 60.0,
                                                        height: 60.0,
                                                        opacity:
                                                            AlwaysStoppedAnimation(
                                                                0.6),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    12.0,
                                                                    0.0,
                                                                    4.0),
                                                        child: AutoSizeText(
                                                          formatDouble(
                                                              totalOne),
                                                          textAlign:
                                                              TextAlign.center,
                                                          minFontSize: 6,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .displaySmall
                                                              .override(
                                                                fontFamily:
                                                                    'Plus Jakarta Sans',
                                                                color: const Color(
                                                                    0xFFdbd7fb),
                                                                fontSize: 20.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      Text(
                                                        'Total ONE',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .override(
                                                                  fontFamily:
                                                                      'Plus Jakarta Sans',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondary,
                                                                  fontSize:
                                                                      12.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.40,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height *
                                                        0.185,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .accent1,
                                                      Color(0xFF414F57)
                                                    ],
                                                    stops: [0.0, 1.0],
                                                    begin: AlignmentDirectional(
                                                        0.03, -1.0),
                                                    end: AlignmentDirectional(
                                                        -0.03, 1.0),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          24.0),
                                                ),
                                                child: Padding(
                                                  padding: EdgeInsets.all(12.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  -1.0, 0.0),
                                                        ),
                                                      ),
                                                      Image.asset(
                                                        'assets/images/bitcoin-wallet.png',
                                                        width: 60.0,
                                                        height: 60.0,
                                                        opacity:
                                                            AlwaysStoppedAnimation(
                                                                0.6),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    12.0,
                                                                    0.0,
                                                                    4.0),
                                                        child: AutoSizeText(
                                                          formatDouble(
                                                              totalStaked),
                                                          textAlign:
                                                              TextAlign.center,
                                                          minFontSize: 6,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .displaySmall
                                                              .override(
                                                                fontFamily:
                                                                    'Plus Jakarta Sans',
                                                                color: const Color(
                                                                    0xFFdbd7fb),
                                                                fontSize: 20.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      Text(
                                                        'Total Staked',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .override(
                                                                  fontFamily:
                                                                      'Plus Jakarta Sans',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondary,
                                                                  fontSize:
                                                                      12.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.40,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height *
                                                        0.185,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .accent1,
                                                      Color(0xFF414F57),
                                                    ],
                                                    stops: [0.0, 1.0],
                                                    begin: AlignmentDirectional(
                                                        0.0, -1.0),
                                                    end: AlignmentDirectional(
                                                        0, 1.0),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          24.0),
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24.0),
                                                    onTap: () async {
                                                      if (rewardThreshold !=
                                                          0.0) {
                                                        toastification.show(
                                                          context: context,
                                                          style:
                                                              ToastificationStyle
                                                                  .fillColored,
                                                          type:
                                                              ToastificationType
                                                                  .info,
                                                          title: Text(
                                                              'You will be notified when your Rewards Threshold has reached $rewardThreshold ONE'),
                                                          autoCloseDuration:
                                                              const Duration(
                                                                  seconds: 7),
                                                        );
                                                      }
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsets.all(12.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Flexible(
                                                            child: Align(
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      -1.0,
                                                                      0.0),
                                                              child: Opacity(
                                                                opacity:
                                                                    alertOpacity,
                                                                child: Icon(
                                                                  Icons
                                                                      .add_alert,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .tertiary,
                                                                  size: 30.0,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          Image.asset(
                                                            'assets/images/money.png',
                                                            width: 60.0,
                                                            height: 60.0,
                                                            opacity:
                                                                AlwaysStoppedAnimation(
                                                                    0.6),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        12.0,
                                                                        0.0,
                                                                        4.0),
                                                            child: AutoSizeText(
                                                              formatDouble(
                                                                  rewards),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              minFontSize: 6,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .displaySmall
                                                                  .override(
                                                                    fontFamily:
                                                                        'Plus Jakarta Sans',
                                                                    color: const Color(
                                                                        0xFFdbd7fb),
                                                                    fontSize:
                                                                        20.0,
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                            ),
                                                          ),
                                                          Text(
                                                            'Rewards',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .labelSmall
                                                                .override(
                                                                  fontFamily:
                                                                      'Plus Jakarta Sans',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondary,
                                                                  fontSize:
                                                                      12.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.40,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height *
                                                        0.185,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .accent1,
                                                      Color(0xFF414F57)
                                                    ],
                                                    stops: [0.0, 1.0],
                                                    begin: AlignmentDirectional(
                                                        0.0, -1.0),
                                                    end: AlignmentDirectional(
                                                        0, 1.0),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          24.0),
                                                ),
                                                child: Padding(
                                                  padding: EdgeInsets.all(12.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  -1.0, 0.0),
                                                        ),
                                                      ),
                                                      Image.asset(
                                                        'assets/images/wallet.png',
                                                        width: 60.0,
                                                        height: 60.0,
                                                        opacity:
                                                            AlwaysStoppedAnimation(
                                                                0.6),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    12.0,
                                                                    0.0,
                                                                    4.0),
                                                        child: AutoSizeText(
                                                          formatDouble(
                                                              availableBalance),
                                                          textAlign:
                                                              TextAlign.center,
                                                          minFontSize: 6,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .displaySmall
                                                              .override(
                                                                fontFamily:
                                                                    'Plus Jakarta Sans',
                                                                color: const Color(
                                                                    0xFFdbd7fb),
                                                                fontSize: 20.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      Text(
                                                        'Balance',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .override(
                                                                  fontFamily:
                                                                      'Plus Jakarta Sans',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondary,
                                                                  fontSize:
                                                                      12.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                splashColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                hoverColor: Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () async {
                                                  final animation = animationsMap[
                                                      'containerOnActionTriggerAnimation'];
                                                  if (animation != null) {
                                                    if (animation.controller
                                                            .duration ==
                                                        null) {
                                                      print(
                                                          'Error: AnimationController has no duration.');
                                                    } else {
                                                      await animation.controller
                                                          .forward(from: 0.0);
                                                    }
                                                  }
                                                  setState(() {
                                                    if (opacity == 1.0)
                                                      opacity = 0.0;
                                                    else
                                                      opacity = 1.0;
                                                  });
                                                },
                                                child: Container(
                                                  width:
                                                      MediaQuery.sizeOf(context)
                                                              .width *
                                                          0.40,
                                                  height:
                                                      MediaQuery.sizeOf(context)
                                                              .height *
                                                          0.185,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .accent1,
                                                        Color(0xFF414F57)
                                                      ],
                                                      stops: [0.0, 1.0],
                                                      begin:
                                                          AlignmentDirectional(
                                                              0.0, -1.0),
                                                      end: AlignmentDirectional(
                                                          0, 1.0),
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24.0),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.all(12.0),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Flexible(
                                                          child: Align(
                                                            alignment:
                                                                AlignmentDirectional(
                                                                    -1.0, 0.0),
                                                          ),
                                                        ),
                                                        Image.asset(
                                                          'assets/images/price-tag.png',
                                                          width: 60.0,
                                                          height: 60.0,
                                                          opacity:
                                                              AlwaysStoppedAnimation(
                                                                  0.6),
                                                        ),
                                                        Opacity(
                                                          opacity: opacity,
                                                          child: Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        12.0,
                                                                        0.0,
                                                                        4.0),
                                                            child: AutoSizeText(onePrice.toStringAsFixed(5),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              minFontSize: 6,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .displaySmall
                                                                  .override(
                                                                    fontFamily:
                                                                        'Plus Jakarta Sans',
                                                                    color: const Color(
                                                                        0xFFdbd7fb),
                                                                    fontSize:
                                                                        20.0,
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          'ONE Price',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .labelSmall
                                                              .override(
                                                                fontFamily:
                                                                    'Plus Jakarta Sans',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondary,
                                                                fontSize: 12.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ).animateOnActionTrigger(animationsMap["containerOnActionTriggerAnimation"]!),
                                              Container(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.40,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height *
                                                        0.185,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .accent1,
                                                      Color(0xFF414F57)
                                                    ],
                                                    stops: [0.0, 1.0],
                                                    begin: AlignmentDirectional(
                                                        0.0, -1.0),
                                                    end: AlignmentDirectional(
                                                        0, 1.0),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          24.0),
                                                ),
                                                child: Padding(
                                                  padding: EdgeInsets.all(12.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  -1.0, 0.0),
                                                        ),
                                                      ),
                                                      Image.asset(
                                                        'assets/images/earnings.png',
                                                        width: 60.0,
                                                        height: 60.0,
                                                        opacity:
                                                            AlwaysStoppedAnimation(
                                                                0.6),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    12.0,
                                                                    0.0,
                                                                    4.0),
                                                        child: AutoSizeText("${formatDouble(totalUSD)} \$",
                                                          textAlign:
                                                              TextAlign.center,
                                                          minFontSize: 6,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .displaySmall
                                                              .override(
                                                                fontFamily:
                                                                    'Plus Jakarta Sans',
                                                                color: const Color(
                                                                    0xFFdbd7fb),
                                                                fontSize: 20.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      Text(
                                                        'Total in USD',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .override(
                                                                  fontFamily:
                                                                      'Plus Jakarta Sans',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondary,
                                                                  fontSize:
                                                                      12.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 0.0, 0.0),
                      child: Text("$timestamp",
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Roboto',
                          color: const Color(0xFFdbd7fb),
                          fontSize: 12.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w500,

                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}
