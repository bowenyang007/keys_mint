import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const keys_to_burn = [
  "Test #29",
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
  function: `${account.address()}::minting::burn_keys_to_mint`,
  arguments: [keys_to_burn],
  type_arguments: [],
};
txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(
    `Burned key ${keys_to_burn} and got gen2. Transaction ${result.version}`
  );
} else {
  console.log(
    "Failed! Got error: ",
    result.vm_status,
    `Transaction ${result.version}`
  );
}
