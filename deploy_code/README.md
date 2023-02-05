Checkout how scripts work in: https://stackoverflow.com/questions/74627977/how-do-i-execute-a-move-script-with-the-aptos-cli.

This script attempts to get the signer of the resource account and deploy code to the resource account from the admin account. 

## How to run this code?
`cd deploy_code`
`aptos move compile && aptos move run-script --compiled-script-path build/run_script/bytecode_scripts/main.mv --profile blah`

## How did I get the bytecode of the code? '
From folder root

`cat move/sources/minting.move | xxd -ps | tr '\n' '\0'`
`cat move/sources/big_vector.move | xxd -ps | tr '\n' '\0'`
`cat move/sources/bucket_table.move | xxd -ps | tr '\n' '\0'`
