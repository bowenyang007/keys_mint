import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const minting_amount = 10;

let payload;
let txnRequest;
let signedTxn;
let transactionRes;
let result;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY_1).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT_1}`);

payload = {
  type: "entry_function_payload",
  function: `0x${process.env.ACCOUNT_GEN2}::minting::wl_mint`,
  arguments: [minting_amount],
  type_arguments: [],
};
txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(
    `Got gen2. Transaction ${result.version}`
  );
} else {
  console.log(
    "Failed! Got error: ",
    result.vm_status,
    `Transaction ${result.version}`
  );
}
