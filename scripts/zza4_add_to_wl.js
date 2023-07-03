import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const wl_addresses = [
  "0x8e8a1d056f959a9d5324cba9cb22700afb6ed2e18827d1ff61f37ce524b3a801"
];
const mint_limit = 1;

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
  function: `0x${process.env.RES_ACCOUNT}::minting::add_to_whitelist`,
  arguments: [wl_addresses, mint_limit],
  type_arguments: []
};
txnRequest = await client.generateTransaction(account.address(), payload, {
  max_gas_amount: 2e6,
});
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Finished adding wl addresses. Gas spent ${result.gas_used * result.gas_unit_price / 1e8} APT. Transaction ${result.version}`);
} else {
  console.log("Failed to add wl addresses, got error: ", result.vm_status);
}
