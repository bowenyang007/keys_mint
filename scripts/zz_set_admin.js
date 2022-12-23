import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
let new_admin_address = "0x";

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
  function: `0x${process.env.RES_ACCOUNT}::minting::set_admin`,
  arguments: [new_admin_address],
  type_arguments: []
};
txnRequest = await client.generateTransaction(account.address(), payload, {
  max_gas_amount: 2e6,
});
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Set admin successful, new admin ${new_admin_address}. Transaction ${result.version}`);
} else {
  console.log("Set admin failed! Got error: ", result.vm_status, `Transaction ${result.version}`);
}