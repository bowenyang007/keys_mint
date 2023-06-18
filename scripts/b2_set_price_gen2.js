import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
// Prices in APT e.g. [.2, 1, 2, 4.5]
const price_config = [.2, 1, 2, 4.55];

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
  function: `0x${process.env.RES_ACCOUNT}::minting::set_price_config`,
  arguments: [price_config.map((price) => price * 1e8)],
  type_arguments: []
};
txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Set to ${price_config} Transaction ${result.version}`);
} else {
  console.log("Failed! Got error: ", result.vm_status, `Transaction ${result.version}`);
}
