import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const key_collection_name = "[REDACTED] Keys";
const collection_description = "test_bla";
const collection_maximum = 7878;
const collection_uri = "test_bla";
const base_token_name = "Test";
const token_description = "I'm a test";
const token_uri = "bla_uri";
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
  function: `0x${process.env.RES_ACCOUNT}::minting::create_keys_collection_with_key_metadata`,
  arguments: [key_collection_name, collection_description, collection_maximum, collection_uri, base_token_name, token_description, token_uri, royalty_payee_address, royalty_points_denominator, royalty_points_numerator],
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