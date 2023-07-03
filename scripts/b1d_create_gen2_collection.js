import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const description = "gen2 yay";
const name = "Gen 2";
const uri = "test gen 2 uri";
const supply = 1000;
const royalty_payee_address = "0xbba67a75a71e675242764071de60b92f4b5c88f6e6cf378aff557bce37e70d9a";
const royalty_points_numerator = 5;
const royalty_points_denominator = 100;

let payload;
let txnRequest;
let signedTxn;
let transactionRes;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT}`);

payload = {
  type: "entry_function_payload",
  function: `0x${process.env.ACCOUNT}::minting::create_collection`,
  arguments: [description, name, uri, supply, royalty_payee_address, royalty_points_denominator, royalty_points_numerator],
  type_arguments: []
};

txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
let result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Keys collection created successfully. Transaction ${result.version}`);
} else {
  console.log("Keys collection created unsuccessfully, got error: ", result.vm_status);
}