import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const destination_collection_name = "new_test_bla";
const collection_description = "new_test_bla";
const collection_maximum = 7878;
const collection_uri = "new_test_bla";
const base_token_name = "New Test";
const token_description = "I'm a test";
const royalty_payee_address = "0xbba67a75a71e675242764071de60b92f4b5c88f6e6cf378aff557bce37e70d9a";
const royalty_points_numerator = 5;
const royalty_points_denominator = 100;
// This should probably always be 1
const token_maximum = 1;

let payload;
let txnRequest;
let signedTxn;
let transactionRes;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT}`);

payload = {
  type: "entry_function_payload",
  function: `0x${process.env.RES_ACCOUNT}::minting::set_destination_collection_config`,
  arguments: [destination_collection_name, collection_description, collection_maximum, collection_uri, base_token_name, royalty_payee_address, token_description, token_maximum, royalty_points_denominator, royalty_points_numerator],
  type_arguments: []
};

txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
let result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Destination collection created successfully. Transaction ${result.version}`);
} else {
  console.log("Destination collection created unsuccessfully, got error: ", result.vm_status);
}