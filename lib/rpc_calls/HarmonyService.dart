import 'dart:convert';
import 'package:http/http.dart' as http;

class HarmonyService {
  final String _rpcUrl; // URL of your Harmony One node's JSON-RPC endpoint
  HarmonyService(this._rpcUrl);

  double availableBalance = 0.0;
  double totalOne = 0.0;
  double totalStaked = 0.0;
  double rewards = 0.0;
  double onePrice = 0.0;
  double totalUSD = 0.0;



  int epoch_now = 0;
  int undelegation_epoch = 0;
  bool undelegation = false;
  double undelegationAmount = 0.0;



  String address ="";

  List <String> myDelegator = [];


  void setAddress (String address){
    this.address = address;
  }


  Future<void> getEpoch() async {
    // Construct JSON-RPC request to get list of validators
    Map<String, dynamic> requestBody = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'hmyv2_getEpoch',
      'params': [],
    };

    // Send HTTP POST request
    Uri url = Uri.parse(_rpcUrl);
    http.Response response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    // Parse JSON response
    Map<String, dynamic> jsonResponse = jsonDecode(response.body);

    // Check if response has error
    if (jsonResponse.containsKey('error')) {
      throw Exception('Error occurred: ${jsonResponse['error']}');
    }
    try {
      epoch_now = int.parse(jsonResponse['result'].toString());
      ;
    } on Exception catch (e) {
      print('Error: $e');
    }
  }





  /**
   * Get available balance of a ONE address
   */
  Future<void> getBalance() async {
    // Construct JSON-RPC request to get list of validators
    Map<String, dynamic> requestBody = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'hmyv2_getBalance',
      'params': [address],
    };

    // Send HTTP POST request
    Uri url = Uri.parse(_rpcUrl);
    http.Response response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    // Parse JSON response
    Map<String, dynamic> jsonResponse = jsonDecode(response.body);

    // Check if response has error
    if (jsonResponse.containsKey('error')) {
      throw Exception('Error occurred: ${jsonResponse['error']}');
    }
    try {
      availableBalance = double.parse(jsonResponse['result'].toString()) / 1e18;
      ;
    } on Exception catch (e) {
      print('Error: $e');
    }
  }

  /**
   * Sum of all of your ONE Coins
   */
  Future<void> getTotaSumOfTokens()  async{
    totalOne = totalStaked + availableBalance + rewards + undelegationAmount;
  }
  /**
   * Get the current price of $ONE from Binance API
   */
  Future<void> getPriceOfOneToken() async{
    try {
      Uri url = Uri.parse("https://api.binance.com/api/v3/ticker/price?symbol=ONEUSDT");
      http.Response response = await http.get(url);
      Map data = jsonDecode(response.body);
      //print(data);

      //Get properties from data

      onePrice = double.parse(data["price"]);

    } on Exception catch (e) {
      print("caught error: $e");
    }
  }
  Future<void> getTotalUSD() async{
    totalUSD = onePrice * totalOne;
  }

  List<String> getmyDelegatorList(){
    return myDelegator;
  }

  
  Future<void> getDelegatorInfo() async {
    try {
      // Construct JSON-RPC request to get delegations by delegator
      Map<String, dynamic> requestBody = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'hmyv2_getDelegationsByDelegator',
        'params': [address], // Replace with your delegator's address
      };

      // Send HTTP POST request
      Uri url = Uri.parse(_rpcUrl);
      http.Response response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // Parse JSON response
      Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      // Check if response has error
      if (jsonResponse.containsKey('error')) {
        throw Exception('Error occurred: ${jsonResponse['error']}');
      }

      // Extract delegations from the response
      List<dynamic> delegations = jsonResponse['result'];

      // Initialize totals
      List<Map<String, dynamic>> delegatorInfo = [];

      // Process each delegation
      for (var delegation in delegations) {
        String validatorAddress = delegation['validator_address'];
        double stakedAmount = double.parse(delegation['amount'].toString()) / 1e18; // Convert AttoONE to ONE
        double _rewards = double.parse(delegation['reward'].toString()) / 1e18; // Convert AttoONE to ONE
        bool hasUndelegations = delegation['Undelegations'] != null && delegation['Undelegations'].isNotEmpty;


        if (stakedAmount > 100){
          myDelegator.add(validatorAddress);
        }
        // Accumulate totals
        totalStaked += stakedAmount;
        rewards += _rewards;

        // Check undelegations
        double undelegationAmount = 0.0;
        if (hasUndelegations) {
          for (var undelegation in delegation['Undelegations']) {
            undelegationAmount += double.parse(undelegation['amount'].toString()) / 1e18;
          }
        }

        // Add delegation details to the list
        delegatorInfo.add({
          'validatorAddress': validatorAddress,
          'stakedAmount': stakedAmount,
          'rewards': rewards,
          'undelegationAmount': undelegationAmount,
        });
      }

      print('Total Staked: $totalStaked ONE');
      print('Total Rewards: $rewards ONE');
      print('Delegator Info: $delegatorInfo');
    } catch (e) {
      print('Error fetching delegator info: $e');
    }
  }
}

