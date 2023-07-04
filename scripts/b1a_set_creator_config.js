import { AptosClient, HexString } from "aptos";
import { AptosAccount } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// PLEASE FILL IN
const token_description = "gen2 test";
const mint_payee_address =
  "0xaa90bb55ecaeb7dfa8a7edee87e2bb0186f53880916c266b418ba17fb5857454";
const collection_description = "gen2 yay";
const collection_name = "Gen 2";
const collection_uri = "test gen 2 uri";
const collection_supply = 200;
const royalty_address =
  "0xaa90bb55ecaeb7dfa8a7edee87e2bb0186f53880916c266b418ba17fb5857454";
const royalty_denominator = 100;
const royalty_numerator = 5;

let payload;
let txnRequest;
let signedTxn;
let transactionRes;

const client = new AptosClient(process.env.NODE_URL);
const private_key = HexString.ensure(process.env.PRIVATE_KEY_GEN2).toUint8Array();
const account = new AptosAccount(private_key, `0x${process.env.ACCOUNT_GEN2}`);

payload = {
  type: "entry_function_payload",
  function: `${account.address()}::minting::set_creator_config`,
  arguments: [
    token_description,
    mint_payee_address,
    collection_description,
    collection_name,
    collection_uri,
    collection_supply,
    royalty_address,
    royalty_denominator,
    royalty_numerator,
  ],
  type_arguments: [],
};

txnRequest = await client.generateTransaction(account.address(), payload);
signedTxn = await client.signTransaction(account, txnRequest);
transactionRes = await client.submitTransaction(signedTxn);
let result = await client.waitForTransactionWithResult(transactionRes.hash);
if (result.success) {
  console.log(
    `Creator config updated successfully. Transaction ${result.version}`
  );
} else {
  console.log("Creator config not updated, got error: ", result.vm_status);
}
