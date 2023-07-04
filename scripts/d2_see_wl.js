import { Provider, Network } from "aptos";
import dotenv from "dotenv";
dotenv.config();

// Nothing to fill in
let payload;
let result;

const provider = new Provider(Network.DEVNET);

payload = {
  function: `0x${process.env.ACCOUNT_GEN2}::minting::view_wl_status`,
  type_arguments: [],
  arguments: [
    "0x5b4248b2bc8066d073f9a57a6a441f1db07f66c7a42ce45bedc0772eed861121",
  ],
};

result = await provider.view(payload);
console.log(result[0]);
