import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
// this needs to be the same as b1d_create_gen2_collection
const collection_name = 'Gen 2';
const key_to_burn = 'Test #5';

let payload;
let txnRequest;
let signedTxn;
let transactionRes;
let result;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT}`);

payload = {
  type: "entry_function_payload",
  function: `0x${process.env.ACCOUNT}::minting::burn_single_to_mint`,
  arguments: [collection_name, key_to_burn],
  type_arguments: []
};
txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Burned key ${key_to_burn} and got gen2. Transaction ${result.version}`);
} else {
  console.log("Failed! Got error: ", result.vm_status, `Transaction ${result.version}`);
}
