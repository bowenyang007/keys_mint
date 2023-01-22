script {
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_token::token::{mutate_tokendata_uri, create_token_data_id};

    fun main(deployer: &signer) {
        let resource_signer = keys_custom::minting::acquire_resource_signer(deployer);
        let creator_addr = signer::address_of(&resource_signer);

        let collection_name = string::utf8(b"");
        let uri = string::utf8(b"");
        
        
        let start: u64 = 0;
        let end_non_inclusive: u64 = 1;

        while (start < end_non_inclusive) {
            let token_name = string::utf8(b"");
            if (start == 0) {
                string::append_utf8(&mut token_name, b"0");
            } else {
                let buffer = vector::empty<u8>();
                let value = copy start;
                while (value != 0) {
                    vector::push_back(&mut buffer, ((48 + value % 10) as u8));
                    value = value / 10;
                };
                vector::reverse(&mut buffer);
                string::append_utf8(&mut token_name, buffer);
            };
            let token_data_id = create_token_data_id(creator_addr, collection_name, token_name);
            mutate_tokendata_uri(&resource_signer, token_data_id, uri);
            start = start + 1;
        };
    }
}