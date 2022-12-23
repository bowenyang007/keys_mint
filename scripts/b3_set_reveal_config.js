import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
// Go to https://www.unixtimestamp.com/ to find unix time
let reveal_time_unix_timestamp_sec = 1671775824;
// This is in octa, i.e. 1 APT = 1e8 octa
let price = 1 * 1e8;

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
  function: `0x${process.env.RES_ACCOUNT}::minting::set_reveal_config`,
  arguments: [reveal_time_unix_timestamp_sec, price],
  type_arguments: []
};
txnRequest = await client.generateTransaction(account.address(), payload, {
  max_gas_amount: 2e6,
});
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Set reveal config. Gas spent ${result.gas_used * result.gas_unit_price / 1e8} APT. Transaction ${result.version}`);
} else {
  console.log("Failed to set reveal config, got error: ", result.vm_status);
}
