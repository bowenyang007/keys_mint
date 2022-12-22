import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const amount_of_keys_to_mint = 30;

let payload;
let txnRequest;
let signedTxn;
let transactionRes;
let result;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT}`);
const MAX_MINT_CHUNK = 100;

let left_to_mint = amount_of_keys_to_mint;
while (left_to_mint > 0) {
  let amount = Math.min(MAX_MINT_CHUNK, left_to_mint);
  payload = {
    type: "entry_function_payload",
    function: `0x${process.env.RES_ACCOUNT}::minting::mint_keys_admin`,
    arguments: [amount],
    type_arguments: []
  };
  txnRequest = await client.generateTransaction(account.address(), payload);
  signedTxn = await client.signTransaction(account, txnRequest);
  transactionRes = await client.submitTransaction(signedTxn);
  result = await client.waitForTransactionWithResult(transactionRes.hash);
  if (result.success) {
    console.log(`Finished minting batch, ${left_to_mint} keys left to mint. Gas spent ${result.gas_used * result.gas_unit_price / 1e8} APT. Transaction ${result.version}`);
    left_to_mint -= amount;
  } else {
    console.log("Minting failed! Got error: ", result.vm_status, `Transaction ${transactionRes.hash}`);
    console.log(`STOPPING MINT!!! ${left_to_mint} keys left to mint. Make sure to change amount to mint to left to mint amount.`);
    break;
  }
}