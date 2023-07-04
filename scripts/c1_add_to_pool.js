import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
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
  // ["uri11", "Common31", "Common", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  // ["uri12", "Common32", "Common", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  // ["uri13", "Common33", "Common", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  // ["uri14", "Common34", "Common", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  // ["uri1", "Common35", "Common", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  // ["uri2", "Common36", "Common", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  // ["uri1", "Common37", "Common", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  ["uri11", "Legendary41", "Legendary", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  ["uri12", "Legendary42", "Legendary", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  ["uri13", "Legendary43", "Legendary", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  ["uri14", "Legendary44", "Legendary", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  ["uri1", "Legendary45", "Legendary", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  ["uri2", "Legendary46", "Legendary", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  ["uri1", "Legendary47", "Legendary", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  // ["uri1", "legendary1", "Legendary", "beak1", "eyes1", "base1", "patterns1", "hair1", "neck1", "clothes1", "body1", "earring1", "background1"],
  // ["uri2", "legendary2", "Legendary", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  // ["uri2", "epic1", "Epic", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  // ["uri2", "epic2", "Epic", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  // ["uri2", "common1", "Common", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
  // ["uri2", "common2", "Common", "beak2", "eyes2", "base2", "patterns2", "hair2", "neck2", "clothes2", "body2", "earring2", "background2"],
];

let payload;
let txnRequest;
let signedTxn;
let transactionRes;
let result;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY_GEN2).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT_GEN2}`);

payload = {
  type: "entry_function_payload",
  function: `${account.address()}::minting::add_tokens`,
  arguments: [token_assets],
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
