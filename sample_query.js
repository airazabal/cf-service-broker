var rp = require('request-promise');
var base64 = require('./client/node_modules/base-64/base64.js');

let auth = base64.encode('apimanager/irazabal@us.ibm.com:Passw0rd!');
console.log("auth: " + auth)
var options = {
  uri: 'https://192.168.225.100/v1/orgs/58dd024ae4b029aafab2fce1/catalogs/58dd024ae4b029aafab2fced/apis/590a67a8e4b01891814ad3d0',

  headers: {
    authorization: auth,
    accept:  'application/vnd.ibm-apim.swagger2+json',
    'Content-Type': 'application/json'
  },
  json: true, // Automatically parses the JSON string in the response
  rejectUnauthorized: false,
};

rp(options)
    .then(function (data) {
      console.log('result: ', data);
    })
    .catch(function (err) {
        // API call failed...
        console.log("failed call");
    });
