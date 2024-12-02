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

  Future<void> getValidators() async {
    try {
      // Construct JSON-RPC request to get list of validators
      Map<String, dynamic> requestBody = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'hmyv2_getAllValidatorAddresses',
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

      List<String> validatorAddresses =
      (jsonResponse['result'] as List<dynamic>)
          .map((e) => e.toString().trim())
          .toList();

      // Fetch staking info in parallel
      await Future.wait(validatorAddresses.map((validatorAddress) async {
        try {
          Map<String, dynamic> stakingInfo = await getStakingInfo(validatorAddress);

          // Check delegations for this validator
          for (var validatorInfo in stakingInfo['validator']['delegations']) {
            String delegatorAddress = validatorInfo['delegator-address'];

            // Check if the delegator is the user address
            if ((delegatorAddress == address && validatorInfo['amount']>100) || (delegatorAddress == address && validatorInfo['undelegations'].isNotEmpty)) {
              // Add this validator to the delegators list
              myDelegator.add(validatorAddress);
              // Accumulate staked amount and rewards
              totalStaked += double.parse(validatorInfo['amount'].toString());
              rewards += double.parse(validatorInfo['reward'].toString());

              if (validatorInfo['undelegations'].isNotEmpty) {
                undelegation = true;
                for (var undelegation in validatorInfo['undelegations']) {
                  undelegationAmount = double.parse(undelegation['amount'].toString());
                  undelegation_epoch = int.parse(undelegation['epoch'].toString());
                }
              }
            }
          }
        } catch (e) {
          print('Error fetching staking info for $validatorAddress: $e');
        }
      }));

      // Convert the total staked amount and rewards from Atto to ONE
      undelegationAmount = undelegationAmount / 1e18;
      totalStaked = totalStaked / 1e18;
      rewards = rewards / 1e18;

      // Optionally print the results
      print('Total amount staked by $address: $totalStaked \$ONE');
      print('Total amount of rewards: $rewards \$ONE');
    } catch (e) {
      print('Error: $e');
    }
  }



  Future<Map<String, dynamic>> getStakingInfo(String validatorAddress) async {
    // Construct JSON-RPC request to get staking info
    Map<String, dynamic> requestBody = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'hmyv2_getValidatorInformation',
      'params': [validatorAddress],
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

    return jsonResponse['result'];
  }
}
