import { AptosClient, HexString, TokenClient } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// NOTE: THIS WILL ONLY WORK IN MAINNET
// This will be 0 unless the script crashes in which case we need to replace with actual starting key number
const starting_key_number = 20;
// This should be the same as in a1_create_keys_collection.js
const key_collection_name = "[REDACTED] Keys";
// This should be the same as in a1_create_keys_collection.js
const base_token_name = "Test";
const address =
  "0x7f3c18f87fdcd0530eba88e415221a937dc4c246b48356125fd2591371f93d22";
const count = 10;

let payload;
let txnRequest;
let signedTxn;
let transactionRes;
let result;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY).toUint8Array();
const private_key_1 = HexString.ensure(process.env.PRIVATE_KEY_1).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT}`);
const account1 = new AptosAccount(private_key_1, `0x${process.env.ACCOUNT_1}`);
const sleep_sec = 0.1;

let gas = 0;
let current_key_number = starting_key_number;
let tokenClient = new TokenClient(client);
for (let i = 0; i < count; i++) {
  let key_name = `${base_token_name} #${current_key_number}`;
  let hash = await tokenClient.directTransferToken(
    account,
    account1,
    process.env.RES_ACCOUNT,
    key_collection_name,
    key_name,
    1,
    0,
  );
    result = await client.waitForTransactionWithResult(hash);
  gas += (result.gas_used * result.gas_unit_price) / 1e8;
  if (result.success) {
    console.log(
      `Sent ${key_name} to ${address} (already completed ${
        i + 1
      } times). Total gas spent so far ${gas} APT. Now sleeping for ${sleep_sec} seconds`
    );
    await new Promise((resolve) => setTimeout(resolve, sleep_sec * 1000));
    current_key_number += 1;
  } else {
    console.log(
      `Sending failed ${key_name} to ${address}! Got error: `,
      result.vm_status
    );
    console.log(`\nSTOPPING SCRIPT. Transaction ${result.version}`);
    break;
  }
}
