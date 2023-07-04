import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const wl_addresses = [
  "0x5b4248b2bc8066d073f9a57a6a441f1db07f66c7a42ce45bedc0772eed861121",
  // "0xfcca5a63a68598ae6d56324df47ebb03c375e8ad82a9d7a1bf6520f16e5377a6",
  // "0xbfb4561cee3ff2d63dc7c314f7c6b36ffde3bb94cfd273b879c47c951600156e",
  // "0x62a81c52504c07f6011f4f5928ecfceca8a63395b5ab14e6b166be25cf26d2d0",
];
const mint_limit = 10;

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
  function: `${account.address()}::minting::add_to_whitelist`,
  arguments: [wl_addresses, mint_limit],
  type_arguments: [],
};
txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(
    `Finished adding wl addresses. Gas spent ${
      (result.gas_used * result.gas_unit_price) / 1e8
    } APT. Transaction ${result.version}`
  );
} else {
  console.log("Failed to add wl addresses, got error: ", result.vm_status);
}
