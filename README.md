# keys_mint
## Pre-requisite
Make sure that nodejs is installed. Follow instructions here: https://docs.npmjs.com/downloading-and-installing-node-js-and-npm#using-a-node-installer-to-install-nodejs-and-npm

I also recommend a text editor like sublime (https://www.sublimetext.com/3) because it will make your life easier. 

## How to use all this
1. Download this package and unzip to Desktop or somewhere else easy to find
2. Open terminal (google if you aren't sure)
(The rest of instructions are all in terminal).
3. Go into the folder containing the unzipped file
   1. `cd <path>` (google if you aren't sure how to do it, e.g. https://www.onmsft.com/how-to/change-directories-command-prompt-windows-10-11)
4. Run `npm install`
5. You'll need to modify .env file with the account & private key
6. You'll need to modify all the script files (find them in the script folder)
   1. Read the next section to see what each of them do. You'll likely need to call them in that order. 
7. Call script with `node scripts/<script_name>.js > <script_name>_log.txt`, e.g. `node scripts/a2_mint_keys.js > a2_mint_keys_log.txt`

## Scripts
The move code is already deployed on mainnet. I added JS scripts to call the major functions. Each of the scripts will need to be modified with the correct configuration. Let's go through each of them. 

* a1_create_keys_collection.js: creates the key collection. You'll need to provide all the necessary fields. I also ask about the token such as the `base_token_name`. It will be used to generate Key #123 (where `Key` is the `base_token_name`)

* a2_mint_keys.js: mints all the keys in the collection in batches of 100. You should definitely put a small number to test how much gas it will cost. Gas cost should be linear. You'll need to mint 1 for each address so the amount should be the same as number of addresses. 

* a3_send_keys.js: You'll provide the list of addresses and we'll call topaz send on them. I also ask for the start key number so that we know which key to start sending first (e.g. if you're sending to 5 people and start key number is 0, then we'll send Key #0 to Key #4 to these 5 people). IMPORTANT: If you ever need to restart (after testing or if the program crashes), you'll need to reset the start number (logs will show latest sent so add 1 to that), as well as removing already processed addresses (they're processed in order and the logs will provide addresses that were processed)

... Will fill the rest later. 

## Code deployment flow
This code is deployed to a resource account so the deployment flow isn't the typical standard deployment. 
* For context, the package was initially deployed via
  * ```aptos move create-resource-account-and-publish-package  --seed 1 --package-dir ./move --address-name keys_custom --named-addresses source_addr=blah --profile BLAH```

The overall flow is 2 parts: first compile package, then take the compiled package and deploy using a move script. 
* Compile, 
  * In the `move` folder, run `aptos move compile --save-metadata`
  * Get the binaries
    * Metadata: `cat build/keys/package-metadata.bcs | xxd -ps | tr '\n' '\0'`
    * big_vector: `cat build/keys/bytecode_modules/big_vector.mv | xxd -ps | tr '\n' '\0'`
    * bucket_table: `cat build/keys/bytecode_modules/bucket_table.mv | xxd -ps | tr '\n' '\0'`
    * minting: `cat build/keys/bytecode_modules/minting.mv | xxd -ps | tr '\n' '\0'`
* In the `deploy_code` folder
  * In the `sources/run_script.move` file, replace the existing binaries with results from previous section. (e.g. swap what's inside of `minting = x""` with results above). 
  * Run `aptos move compile && aptos move run-script --compiled-script-path build/run_script/bytecode_scripts/main.mv --profile bla`