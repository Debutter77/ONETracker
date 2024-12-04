const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { google } = require('googleapis');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Standardkonfiguration für Funktionen (z. B. 512 MB Speicher)
const runtimeOpts = {
  memory: '512MB',
  timeoutSeconds: 60, // Optional, falls Funktionen länger laufen dürfen
};


const HARMONY_RPC_URL = 'https://rpc.s0.t.hmny.io';

// OAuth scopes for Firebase Cloud Messaging v1 API
const MESSAGING_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const SCOPES = [MESSAGING_SCOPE];

// Get OAuth2 access token to authorize Firebase Messaging requests
async function getAccessToken() {
  const key = require('./serviceAccountKey.json'); // Replace with the correct path to your service account key file
  const jwtClient = new google.auth.JWT(
    key.client_email,
    null,
    key.private_key,
    SCOPES
  );
  const tokens = await jwtClient.authorize();
  return tokens.access_token;
}

// Function to send notification via Firebase Messaging v1 API
async function sendNotification(fcmToken, title, body) {
  const accessToken = await getAccessToken();

  const message = {
    message: {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
    },
  };

  const response = await axios.post(
    'https://fcm.googleapis.com/v1/projects/harmonyrewards/messages:send',
    message,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    }
  );

  return response.data;
}

// ------------------ HTTP API Part ------------------

// HTTP route to save user data
const express = require('express');
const app = express();

app.use(express.json()); // Middleware to parse JSON requests

// Save user data route
app.post('/saveUserData', async (req, res) => {
  const { uid, address, fcmToken, rewardsTrigger, notificationSent, notificationSentForValidator, delegations } = req.body;

  try {
    // Ensure 'delegations' is properly structured as a list of objects
    if (!Array.isArray(delegations) || delegations.some(d => !d.validatorAddress)) {
      return res.status(400).send({ error: 'Invalid delegations format' });
    }

    // Reference to the user's address data in Firebase
    const addressRef = admin.database().ref(`users/${uid}/${address}`);

    // Check if the address already exists for the user
    const addressSnapshot = await addressRef.once('value');

    if (addressSnapshot.exists()) {
      // If the address exists, update the existing data
      await addressRef.update({
        fcmToken,
        rewardsTrigger,
        notificationSent: notificationSent || false,
        notificationSentForValidator: notificationSentForValidator || false,
        delegations: delegations // Update the delegations list
      });

      res.status(200).send({ message: 'User data updated successfully' });
    } else {
      // If the address doesn't exist, create a new entry
      await addressRef.set({
        fcmToken,
        rewardsTrigger,
        notificationSent: notificationSent || false,
        notificationSentForValidator: notificationSentForValidator || false,
        delegations: delegations, // Save the delegations list
        timestamp: Date.now(), // Add the current timestamp
      });

      res.status(200).send({ message: 'New user data created successfully' });
    }
  } catch (error) {
    console.error('Error saving user data:', error);
    res.status(500).send({ error: 'Failed to save user data' });
  }
});



// Route to save or update user details like current active address, address history, and favoriteAddressMap
app.post('/saveOrUpdateUserDetails', async (req, res) => {
  const { uid, currentAddress, addressListHistory, favoriteAddressMap, fcmToken} = req.body;

  try {
    // Reference to the user's data in Firebase
    const userRef = admin.database().ref(`users/${uid}`);

    // Fetch the current data to decide whether to update or set a new one
    const userSnapshot = await userRef.once('value');
    let updates = {};

    if (userSnapshot.exists()) {
      // If user data exists, update specific fields
      updates = {
        fcmToken: fcmToken,
        currentAddress: currentAddress || userSnapshot.val().currentAddress,
        addressListHistory: addressListHistory || userSnapshot.val().addressListHistory || [],
        favoriteAddressMap: favoriteAddressMap || userSnapshot.val().favoriteAddressMap || {}
      };

      await userRef.update(updates);
      res.status(200).send({ message: 'User details updated successfully', data: updates });
    } else {
      // If user data does not exist, set new data
      await userRef.set({
        fcmToken: fcmToken,
        currentAddress: currentAddress || '',
        addressListHistory: addressListHistory || [],
        favoriteAddressMap: favoriteAddressMap || {}
      });

      res.status(200).send({ message: 'New user details created successfully' });
    }
  } catch (error) {
    console.error('Error saving/updating user details:', error);
    res.status(500).send({ error: 'Failed to save or update user details' });
  }
});


app.get('/getUserDetailsByFcmToken/:fcmToken', async (req, res) => {
  const fcmToken = req.params.fcmToken;

  try {
    // Reference to the 'users' node in Firebase
    const usersRef = admin.database().ref('users');

    // Query the database for users with the specified fcmToken
    const snapshot = await usersRef.orderByChild('fcmToken').equalTo(fcmToken).once('value');

    if (snapshot.exists()) {
      let userData = null;
      let uid = null;

      snapshot.forEach(childSnapshot => {
        uid = childSnapshot.key; // Get the UID of the user
        userData = childSnapshot.val(); // Get the user data
      });

      res.status(200).send({
        uid: uid,
        data: {
          currentAddress: userData.currentAddress,
          addressListHistory: userData.addressListHistory || [],
          favoriteAddressMap: userData.favoriteAddressMap || {}
        }
      });
    } else {
      res.status(404).send({ error: 'User not found for the provided FCM token' });
    }
  } catch (error) {
    console.error('Error retrieving user details:', error);
    res.status(500).send({ error: 'Failed to retrieve user details' });
  }
});




app.post('/deleteUser', async (req, res) => {
  const { uid } = req.body;

  try {
    // Check if the user exists
    const userSnapshot = await admin.database().ref(`users/${uid}`).once('value');

    if (userSnapshot.exists()) {
      // If user exists, remove the user
      await admin.database().ref(`users/${uid}`).remove();
      res.status(200).send({ message: `User with uid ${uid} successfully deleted.` });
    } else {
      // If the user does not exist
      res.status(404).send({ error: `User with uid ${uid} not found.` });
    }
  } catch (error) {
    console.error('Error deleting user data:', error);
    res.status(500).send({ error: 'Failed to delete user data.' });
  }
});


app.post('/deleteAddress', async (req, res) => {
  const { uid, address } = req.body;

  try {
    // Check if the address exists under the user
    const addressSnapshot = await admin.database().ref(`users/${uid}/${address}`).once('value');

    if (addressSnapshot.exists()) {
      // If address exists, remove it
      await admin.database().ref(`users/${uid}/${address}`).remove();
      res.status(200).send({ message: `Address ${address} for user with uid ${uid} successfully deleted.` });
    } else {
      // If the address does not exist
      res.status(404).send({ error: `Address ${address} for user with uid ${uid} not found.` });
    }
  } catch (error) {
    console.error('Error deleting address data:', error);
    res.status(500).send({ error: 'Failed to delete address data.' });
  }
});



app.get('/getUserData/:uid/:address', async (req, res) => {
  const uid = req.params.uid;
  const address = req.params.address;

  try {
    // Fetch user data for the given uid and address
    const snapshot = await admin.database().ref(`users/${uid}/${address}`).once('value');

    if (snapshot.exists()) {
      const addressData = snapshot.val();

      // Check if 'notificationSent' and 'notificationSentForValidator' exist and return their statuses
      const notificationSent = addressData.notificationSent;
      const notificationSentForValidator = addressData.notificationSentForValidator;

      res.status(200).send({
        addressData,
        notificationSentStatus: notificationSent !== undefined ? (notificationSent ? 'true' : 'false') : 'Notification status not found',
        notificationSentForValidatorStatus: notificationSentForValidator !== undefined ? (notificationSentForValidator ? 'true' : 'false') : 'Validator notification status not found',
      });
    } else {
      res.status(404).send({ error: 'Address data not found for the given user' });
    }
  } catch (error) {
    console.error('Error retrieving user address data:', error);
    res.status(500).send({ error: 'Failed to retrieve user address data' });
  }
});



app.get('/getRewardsThreshold/:uid/:address', async (req, res) => {
  const uid = req.params.uid;
  const address = req.params.address;

  try {
    // Fetch rewards threshold for the given uid and address
    const snapshot = await admin.database().ref(`users/${uid}/${address}/rewardsTrigger`).once('value');

    if (snapshot.exists()) {
      const rewardsThreshold = snapshot.val();

      res.status(200).send({
        rewardsThreshold,
        message: `Rewards threshold for address ${address} retrieved successfully`
      });
    } else {
      res.status(404).send({ error: 'Rewards threshold not found for the given address' });
    }
  } catch (error) {
    console.error('Error retrieving rewards threshold:', error);
    res.status(500).send({ error: 'Failed to retrieve rewards threshold' });
  }
});


// Add a new route to get all addresses for a user
app.get('/getUserAddresses/:uid', async (req, res) => {
  const uid = req.params.uid;

  try {
    const snapshot = await admin.database().ref(`users/${uid}`).once('value');

    if (snapshot.exists()) {
      const userData = snapshot.val();
      const addresses = Object.keys(userData); // Get all addresses

      res.status(200).send({
        addresses: addresses,
      });
    } else {
      res.status(404).send({ error: 'User data not found' });
    }
  } catch (error) {
    console.error('Error retrieving user addresses:', error);
    res.status(500).send({ error: 'Failed to retrieve user addresses' });
  }
});








// Expose the HTTP API
exports.api = functions.region('europe-west1').runWith(runtimeOpts).https.onRequest(app);

// ------------------ Original Firebase Functions ------------------

// Fetch rewards for a specific address
async function getRewardsForAddress(address) {
  try {
    const electedValidatorsResponse = await axios.post(HARMONY_RPC_URL, {
      jsonrpc: '2.0',
      method: 'hmyv2_getAllValidatorAddresses',
      params: [],
      id: 1
    });

    const electedValidatorAddresses = electedValidatorsResponse.data.result;
    let totalRewards = 0;

    const validatorInfoPromises = electedValidatorAddresses.map(validatorAddress =>
      axios.post(HARMONY_RPC_URL, {
        jsonrpc: '2.0',
        method: 'hmyv2_getValidatorInformation',
        params: [validatorAddress],
        id: 1
      })
    );

    const validatorInfoResponses = await Promise.all(validatorInfoPromises);

    validatorInfoResponses.forEach(response => {
      const validatorInfo = response.data.result;
      const delegations = validatorInfo.validator.delegations || [];
      const addressDelegation = delegations.find(delegation => delegation['delegator-address'] === address);

      if (addressDelegation) {
        totalRewards += addressDelegation.reward;
      }
    });

    const rewardsInOne = totalRewards / 1e18;
    return rewardsInOne;
  } catch (error) {
    console.error('Error fetching rewards:', error);
    throw error;
  }
}



app.get('/getDelegationsInfo/:delegatorAddress', async (req, res) => {
  const { delegatorAddress } = req.params;
  const { delegations } = req.query; // Erwartet eine JSON-codierte Liste von Validator-Adressen

  try {
    const validatorAddresses = JSON.parse(delegations);

    if (!Array.isArray(validatorAddresses) || validatorAddresses.length === 0) {
      return res.status(400).send({ error: 'Invalid or empty delegations list provided.' });
    }

    const HARMONY_RPC_URL = 'https://rpc.s0.t.hmny.io'; // Beispiel-URL, anpassen falls nötig

    // Funktion zum Abrufen von Informationen über einen einzelnen Validator
    async function getValidatorInfo(validatorAddress) {
      try {
        const response = await axios.post(HARMONY_RPC_URL, {
          jsonrpc: '2.0',
          method: 'hmyv2_getValidatorInformation',
          params: [validatorAddress],
          id: 1,
        });

        return response.data.result;
      } catch (error) {
        console.error(`Error fetching info for validator ${validatorAddress}:`, error);
        return null;
      }
    }

    const validatorDetails = await Promise.all(validatorAddresses.map(getValidatorInfo));

    // Filter ungültige oder nicht gefundene Validatoren
    const validDetails = validatorDetails.filter(detail => detail !== null);

    // Zusammenstellen der Antwort
    const responseInfo = validDetails.map(validatorInfo => {
      const delegations = validatorInfo.validator.delegations || [];
      const delegatorData = delegations.find(
        delegation => delegation['delegator-address'] === delegatorAddress
      );

      return {
        name: validatorInfo.validator.name || 'Unknown',
        isElected: validatorInfo['epos-status'] === 'currently elected',
        stakedAmount: delegatorData ? parseFloat(delegatorData.amount) / 1e18 : 0,
        rewards: delegatorData ? parseFloat(delegatorData.reward) / 1e18 : 0,
      };
    });

    res.status(200).send({ delegations: responseInfo });
  } catch (error) {
    console.error('Error retrieving delegations info:', error);
    res.status(500).send({ error: 'Failed to retrieve delegations information.' });
  }
});


function shortAddress(address) {
  if (address.includes("Insert")) {
    return address; // If the address contains "Insert", return it as is
  }
  if (address.length <= 10) {
    return address; // If the address is too short, don't shorten it
  }
  const firstPart = address.substring(0, 10); // Get the first 10 characters
  const lastPart = address.substring(address.length - 8); // Get the last 8 characters

  return `${firstPart}...${lastPart}`; // Concatenate with "..."
}

// Function to check rewards and notify users
exports.checkRewardsAndNotify = functions
  .region('europe-west1')
  .runWith(runtimeOpts)
  .pubsub.schedule('every 60 minutes')
  .onRun(async (context) => {
    try {
      const usersSnapshot = await admin.database().ref('users').once('value');
      const users = usersSnapshot.val();

      for (const uid in users) {
        const userAddresses = users[uid];

        for (const address in userAddresses) {
          const user = userAddresses[address];
          const rewards = await getRewardsForAddress(address);
          const TARGET_REWARD = user.rewardsTrigger;

          if (rewards >= TARGET_REWARD && !user.notificationSent) {
            const payloadTitle = 'Rewards Milestone Reached!';
            const payloadBody = `The rewards of the Wallet ${shortAddress(address)} have reached ${rewards.toFixed(2)} ONE tokens!`;
            try {
              const response = await sendNotification(user.fcmToken, payloadTitle, payloadBody);
              console.log(`Notification sent successfully to ${uid} for ${address}:`, response);

              // Update the flag in the database to mark that the notification was sent
              await admin.database().ref(`users/${uid}/${address}`).update({ notificationSent: true, rewardsTrigger: null });
            } catch (notificationError) {
              console.error(`Error sending notification to ${uid} for ${address}:`, notificationError);
            }
          } else {
            console.log(`Current rewards (${rewards.toFixed(2)}) for ${uid}/${address} have not reached the target (${TARGET_REWARD.toFixed(2)}) yet.`);
          }
        }
      }
    } catch (error) {
      console.error('Error checking rewards and sending notification:', error);
    }
  });


// Function to check validator election status and notify users
exports.checkValidatorElectionAndNotify = functions
  .region('europe-west1')
  .runWith(runtimeOpts)
  .pubsub.schedule('every 60 minutes')
  .onRun(async (context) => {
    try {
      const usersSnapshot = await admin.database().ref('users').once('value');
      const users = usersSnapshot.val();

      for (const uid in users) {
        const userAddresses = users[uid];

        for (const address in userAddresses) {
          const user = userAddresses[address];
          const fcmToken = user.fcmToken;
          const delegations = user.delegations;

          for (const delegation of delegations) {
            const validatorAddress = delegation.validatorAddress;

            // Fetch validator information to get the name and election status
            const validatorInfoResponse = await axios.post(HARMONY_RPC_URL, {
              jsonrpc: '2.0',
              method: 'hmyv2_getValidatorInformation',
              params: [validatorAddress],
              id: 1,
            });

            const validatorInfo = validatorInfoResponse.data.result;
            const isElected = validatorInfo['epos-status'] === 'currently elected';
            const validatorName = validatorInfo.validator.name || validatorInfo.validator['name'] || 'Unknown Validator';

            if (!isElected) {
              const now = Date.now();
              const lastNotified = user.lastValidatorNotification || 0;
              const oneDayInMs = 24 * 60 * 60 * 1000;

              if (now - lastNotified > oneDayInMs) {
                const payloadTitle = 'Validator Not Elected!';
                const payloadBody = `The validator ${validatorName} you are delegating to is no longer elected.`;

                try {
                  const response = await sendNotification(fcmToken, payloadTitle, payloadBody);
                  console.log(`Notification sent successfully to ${uid} for ${address}:`, response);

                  // Update the timestamp for the last notification
                  await admin.database().ref(`users/${uid}/${address}`).update({
                    lastValidatorNotification: now,
                  });
                } catch (notificationError) {
                  console.error(`Error sending notification to ${uid} for ${address}:`, notificationError);
                }
              } else {
                console.log(`Notification for ${validatorName} already sent within the last 24 hours.`);
              }
            }
          }
        }
      }
    } catch (error) {
      console.error('Error checking validators and sending notification:', error);
    }
  });


