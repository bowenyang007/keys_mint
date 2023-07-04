import { Provider, Network } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// Nothing to fill in
let payload;
let result;

const provider = new Provider(Network.DEVNET);

payload = {
  function: `0x${process.env.ACCOUNT_GEN2}::minting::view_pool_length`,
  type_arguments: [],
  arguments: ["5"],
};

result = await provider.view(payload);
console.log(result[0]);
