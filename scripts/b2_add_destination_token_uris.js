import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
// Try 1000 at a time to make sure gas doesn't blow up
const token_uris = [
  "test_uri_1.json",
  "test_uri_2.json",
  "test_uri_3.json"
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
  function: `0x${process.env.RES_ACCOUNT}::minting::add_tokens`,
  arguments: [token_uris],
  type_arguments: []
};
txnRequest = await client.generateTransaction(account.address(), payload, {
  max_gas_amount: 2e6,
});
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Finished adding tokens. Gas spent ${result.gas_used * result.gas_unit_price / 1e8} APT. Transaction ${result.version}`);
} else {
  console.log("Failed to add tokens, got error: ", result.vm_status);
}
