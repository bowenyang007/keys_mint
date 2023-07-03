import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const token_description = "gen2 test";
const mint_payee_address = "0xaa90bb55ecaeb7dfa8a7edee87e2bb0186f53880916c266b418ba17fb5857454";

let payload;
let txnRequest;
let signedTxn;
let transactionRes;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT}`);

payload = {
  type: "entry_function_payload",
  function: `0x${process.env.ACCOUNT}::minting::set_creator_config`,
  arguments: [token_description, mint_payee_address],
  type_arguments: []
};

txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
let result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(`Creator config updated successfully. Transaction ${result.version}`);
} else {
  console.log("Creator config not updated, got error: ", result.vm_status);
}