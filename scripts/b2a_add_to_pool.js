import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
// this needs to be the same as b1d_create_gen2_collection
const batch = 'batch_1';
// Each of these need to have 13 elements and follow this order
// token_uri,
// token_name,
// rarity,
// beak,
// eyes,
// base,
// patterns,
// hair,
// neck,
// clothes,
// body,
// earring,
// background
const token_assets = [
  ["uri1", "name1", "rarity1", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  ["uri2", "name2", "rarity2", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
];

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
  function: `0x${process.env.ACCOUNT}::minting::add_tokens`,
  arguments: [batch, token_assets],
  type_arguments: []
};
txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Added assets. Transaction ${result.version}`);
} else {
  console.log("Failed! Got error: ", result.vm_status, `Transaction ${result.version}`);
}
