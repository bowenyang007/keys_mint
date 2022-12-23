import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
import csvtojson from "convert-csv-to-json";
dotenv.config();

// NOTE: THIS WILL ONLY WORK IN MAINNET
// COPY THE LIST OF ADDRESS INTO THE CSV FILE
const CSV_FILE = "./scripts/addr.csv";

// This will be 0 unless the script crashes in which case we need to replace with actual starting key number
const starting_key_number = 0;
// This should be the same as in a1_create_keys_collection.js
const key_collection_name = "TEST COLLECTION";
// This should be the same as in a1_create_keys_collection.js
const base_token_name = "KEY";

let payload;
let txnRequest;
let signedTxn;
let transactionRes;
let result;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT}`);
const sleep_sec = .5;

let gas = 0;
let current_key_number = starting_key_number;
let addresses = csvtojson.fieldDelimiter(',').getJsonFromCsv(CSV_FILE);
for (var drop_setting of addresses) {
  let addr = drop_setting["owner"];
  let count = drop_setting["cnt"];
  for (let i = 0; i < count; i++) {
    let key_name = `${base_token_name} #${current_key_number}`;    
    payload = {
      type: "entry_function_payload",
      function: "0x2c7bccf7b31baf770fdbcc768d9e9cb3d87805e255355df5db32ac9a669010a2::inbox::offer_script",
      arguments: [addr, process.env.RES_ACCOUNT, key_collection_name, key_name, 0, 1],
      type_arguments: []
    };
    txnRequest = await client.generateTransaction(account.address(), payload);
    signedTxn = await client.signTransaction(account, txnRequest);
    transactionRes = await client.submitTransaction(signedTxn);
    result = await client.waitForTransactionWithResult(transactionRes.hash);
    gas += result.gas_used * result.gas_unit_price / 1e8;
    if (result.success) {
      console.log(`Sent ${key_name} to ${addr} (already completed ${i + 1} times). Total gas spent so far ${gas} APT. Now sleeping for ${sleep_sec} seconds`);
      await new Promise(resolve => setTimeout(resolve, sleep_sec * 1000));
      current_key_number += 1;
    } else {
      console.log(`Sending failed ${key_name} to ${addr}! Got error: `, result.vm_status);
      console.log(`\nSTOPPING SCRIPT. Transaction ${result.version}`);
      console.log(`\nPLEASE REMOVE ALREADY PROCESSED ADDRESS FROM list_of_addresses AND UPDATE starting_key_number`);
      break;
    }
  }
}