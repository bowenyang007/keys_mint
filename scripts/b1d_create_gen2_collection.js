import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// Nothing to fill

let payload;
let txnRequest;
let signedTxn;
let transactionRes;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY_GEN2).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT_GEN2}`);

payload = {
  type: "entry_function_payload",
  function: `${account.address()}::minting::create_collection`,
  arguments: [],
  type_arguments: []
};

txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
let result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Gen2 collection created successfully. Transaction ${result.version}`);
} else {
  console.log("Gen2 collection created unsuccessfully, got error: ", result.vm_status);
}