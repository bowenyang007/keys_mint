import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const list_of_addresses = [
  "0x9c29bac6d9f5ec5c9e33a5c12522205b71637b10ed2bc5027917ad60ee5f7536",
  "0x9c29bac6d9f5ec5c9e33a5c12522205b71637b10ed2bc5027917ad60ee5f7536"
];
// This will be 0 unless the script crashes in which case we need to replace with actual starting key number
const starting_key_number = 0;

let payload;
let txnRequest;
let signedTxn;
let transactionRes;
let result;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT}`);

let gas = 0;
for (let addr in list_of_addresses) {
  // THIS DOESN'T WORK YET
  payload = {
    type: "entry_function_payload",
    function: "0x2c7bccf7b31baf770fdbcc768d9e9cb3d87805e255355df5db32ac9a669010a2::inbox::offer_script",
    arguments: [addr, ],
    type_arguments: []
  };
  txnRequest = await client.generateTransaction(account.address(), payload);
  signedTxn = await client.signTransaction(account, txnRequest);
  transactionRes = await client.submitTransaction(signedTxn);
  result = await client.waitForTransactionWithResult(transactionRes.hash);
  gas += result.gas_used * result.gas_unit_price / 1e8;
  if (result.success) {
    console.log(`Sent ${key_name} to ${addr}. Total gas spent so far ${gas} APT`);
  } else {
    console.log("Sending failed! Got error: ", result.vm_status);
    console.log(`\nSTOPPING SCRIPT. Transaction ${result.version}`);
    console.log(`\nPLEASE REMOVE ALREADY PROCESSED ADDRESS FROM list_of_addresses AND UPDATE starting_key_number`);
    break;
  }
}