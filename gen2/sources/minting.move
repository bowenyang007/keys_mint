module gen2_mint::minting_test5 {
    use std::error;
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::vector;

    use gen2_mint::big_vector::{Self, BigVector};
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_token_objects::property_map;
    use aptos_framework::event;
    use aptos_framework::timestamp;

    /// The account is not authorized to update the resources.
    const ENOT_AUTHORIZED: u64 = 1;
    /// The whitelist account address does not exist.
    const EACCOUNT_DOES_NOT_EXIST: u64 = 3;
    /// Adding new token uris exceeds the collection maximum.
    const EEXCEEDS_COLLECTION_MAXIMUM: u64 = 5;
    /// No enough destination tokens left in the collection.
    const ENO_ENOUGH_TOKENS_LEFT: u64 = 9;
    /// The account trying to mint during the whitelist minting time is not whitelisted.
    const EACCOUNT_NOT_WHITELISTED: u64 = 10;
    /// Invalid numerator and denominator combo for the collection royalty setting.
    const EINVALID_ROYALTY_NUMERATOR_DENOMINATOR: u64 = 11;
    /// The collection is already created.
    const ECOLLECTION_ALREADY_CREATED: u64 = 12;
    /// The config has not been initialized.
    const ECONFIG_NOT_INITIALIZED: u64 = 13;
    /// The specified amount exceeds the number of mints allowed for the specified whitelisted account.
    const EAMOUNT_EXCEEDS_MINTS_ALLOWED: u64 = 14;
    /// The source certificate id not found in the signer's account.
    const ETOKEN_ID_NOT_FOUND: u64 = 15;
    /// Can only exchange after the reveal starts.
    const ECANNOT_EXCHANGE_BEFORE_REVEAL_STARTS: u64 = 16;
    /// Batch not found
    const EBATCH_NOT_FOUND: u64 = 17;
    /// Probability config needs to be a 4x4 matrix
    const EPROBABILITY_CONFIG_WRONG_LENGTH: u64 = 18;
    /// Probabilities need to add up to 100 both horizontally and vertically
    const EPROBABILITY_CONFIG_INCORRECT_SUM: u64 = 17;
    /// Price config needs to be a length 4 array
    const EPRICE_CONFIG_WRONG_LENGTH: u64 = 19;

    // /// WhitelistMintConfig stores information about whitelist minting.
    // struct WhitelistMintConfig has key {
    //     whitelisted_address: BucketTable<address, u64>,
    // }

    struct TokenPool has key {
        tier1_pool: BigVector<TokenAsset>,
        tier2_pool: BigVector<TokenAsset>,
        tier3_pool: BigVector<TokenAsset>,
        tier4_pool: BigVector<TokenAsset>,
    }

    struct TokenAsset has drop, store {
        token_uri: String,
        token_name: String,
        // Mask traits
        rarity: String,
        beak: String,
        eyes: String,
        base: String,
        patterns: String,
        // Person traits
        hair: String,
        neck: String,
        clothes: String,
        body: String,
        earring: String,
        background: String,
    }

    /// Emitted when a user mints a source certificate token.
    struct MintingEvent has drop, store {
        token_receiver_address: address,
        token_data_id: address,
    }

    /// There are 4 buckets total of destination tokens and 3 batches of keys, this config
    /// will be used to determine the probability of minting a destination token from a batch.
    /// e.g. batch_one: [25, 25, 25, 25]
    struct DestinationProbabilityConfig has key {
        batch_one: vector<u64>,
        batch_two: vector<u64>,
        batch_three: vector<u64>,
        general: vector<u64>,
    }

    /// This will set the price for each batch, in octa
    struct PriceConfig has key {
        batch_one: u64,
        batch_two: u64,
        batch_three: u64,
        general: u64,
    }

    /// The gen2 token
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Gen2Token has key {
        /// Used to burn.
        burn_ref: token::BurnRef,
        /// Used to control freeze.
        transfer_ref: object::TransferRef,
        /// Used to mutate fields
        mutator_ref: token::MutatorRef,
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef,
        /// Used to emit MintEvent
        _events: event::EventHandle<MintEvent>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct MaskTraits has key {
        rarity: String,
        beak: String,
        eyes: String,
        base: String,
        patterns: String,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct PersonTraits has key {
        hair: String,
        neck: String,
        clothes: String,
        body: String,
        earring: String,
        background: String,
    }

    struct MintEvent has drop, store {
        token_receiver_address: address,
        token_data_id: address,
    }

    /// This will set the probability config which is a 4x4 matrix
    public entry fun set_probability_config(admin: &signer, probabilities: vector<vector<u64>>) acquires DestinationProbabilityConfig {
        if (signer::address_of(admin) != @gen2_mint) {
            assert!(false, error::permission_denied(ENOT_AUTHORIZED)); 
        };

        let batch = 1;
        assert!(vector::length(&probabilities) == 4, error::invalid_argument(EPROBABILITY_CONFIG_WRONG_LENGTH));
        let batch_1_config: vector<u64> = vector[];
        let batch_2_config: vector<u64> = vector[];
        let batch_3_config: vector<u64> = vector[];
        let general: vector<u64> = vector[];
        while (batch < 5) {
            // make sure that the sum of the probabilities is 100 for each batch
            let batch_config: vector<u64> = *vector::borrow(&probabilities, batch - 1);
            let s = sum(&batch_config);
            assert!(vector::length(&batch_config) == 4, error::invalid_argument(EPROBABILITY_CONFIG_WRONG_LENGTH));
            assert!(s == 100, error::invalid_argument(EPROBABILITY_CONFIG_INCORRECT_SUM));

            if (batch == 1) {
                batch_1_config = batch_config;
            } else if (batch == 2) {
                batch_2_config = batch_config;
            } else if (batch == 3) {
                batch_3_config = batch_config;
            } else {
                general = batch_config;
            };
            batch = batch + 1;
        };
        // makes sure that the sum for each bucket is also 100
        let i = 0;
        while (i < 4) {
            let s = sum(&vector[*vector::borrow(&batch_1_config, i), *vector::borrow(&batch_2_config, i), *vector::borrow(&batch_3_config, i), *vector::borrow(&general, i)]);
            assert!(s == 100, error::invalid_argument(EPROBABILITY_CONFIG_INCORRECT_SUM));
            i = i + 1;
        };
        
        if (!exists<DestinationProbabilityConfig>(@gen2_mint)) {
            move_to(admin, DestinationProbabilityConfig {
                batch_one: batch_1_config,
                batch_two: batch_2_config,
                batch_three: batch_3_config,
                general,
            })
        } else {
            let probability_config = borrow_global_mut<DestinationProbabilityConfig>(@gen2_mint);
            probability_config.batch_one = batch_1_config;
            probability_config.batch_two = batch_2_config;
            probability_config.batch_three = batch_3_config;
            probability_config.general = general;
        }
    }

    /// This will set the price per batch
    public entry fun set_price_config(admin: &signer, prices: vector<u64>) acquires PriceConfig {
        if (signer::address_of(admin) != @gen2_mint) {
            assert!(false, error::permission_denied(ENOT_AUTHORIZED)); 
        };

        let batch_1_price: u64 = 0;
        let batch_2_price: u64 = 0;
        let batch_3_price: u64 = 0;
        let general_price: u64 = 0;
        let batch = 1;
        assert!(vector::length(&prices) == 4, error::invalid_argument(EPRICE_CONFIG_WRONG_LENGTH));
        while (batch < 5) {
            let price = *vector::borrow(&prices, batch - 1);
            if (batch == 1) {
                batch_1_price = price;
            } else if (batch == 2) {
                batch_2_price = price;
            } else if (batch == 3) {
                batch_3_price = price;
            } else {
                general_price = price;
            };
            batch = batch + 1;
        };

        if (!exists<PriceConfig>(@gen2_mint)) {
            move_to(admin, PriceConfig {
                batch_one: batch_1_price,
                batch_two: batch_2_price,
                batch_three: batch_3_price,
                general: general_price,
            })
        } else {
            let probability_price = borrow_global_mut<PriceConfig>(@gen2_mint);
            probability_price.batch_one = batch_1_price;
            probability_price.batch_two = batch_2_price;
            probability_price.batch_three = batch_3_price;
            probability_price.general = general_price;
        }
    }

    // /// Add user addresses to the whitelist for the keys collection
    // public entry fun add_to_whitelist(
    //     admin: &signer,
    //     wl_addresses: vector<address>,
    //     mint_limit: u64
    // ) acquires NFTMintConfig, WhitelistMintConfig {
    //     let nft_mint_config = borrow_global_mut<NFTMintConfig>(@gen2_mint);
    //     assert!(signer::address_of(admin) == nft_mint_config.admin, error::permission_denied(ENOT_AUTHORIZED));
    //     if (!exists<WhitelistMintConfig>(@gen2_mint)) {
    //         let resource_account = create_signer_with_capability(&nft_mint_config.signer_cap);
    //         move_to(&resource_account, WhitelistMintConfig {
    //             whitelisted_address: bucket_table::new<address, u64>(10),
    //         });
    //     };
    //     let whitelist_mint_config = borrow_global_mut<WhitelistMintConfig>(@gen2_mint);

    //     let i = 0;
    //     while (i < vector::length(&wl_addresses)) {
    //         let addr = *vector::borrow(&wl_addresses, i);
    //         // assert that the specified address exists
    //         assert!(account::exists_at(addr), error::invalid_argument(EACCOUNT_DOES_NOT_EXIST));
    //         bucket_table::add(&mut whitelist_mint_config.whitelisted_address, addr, mint_limit);
    //         i = i + 1;
    //     };
    // }

    // /// Add destination tokens, which are the actual art tokens. The users will be able to exchange their source certificate token
    // /// for a randomized destination token after the reveal time starts.
    // public entry fun add_tokens(
    //     admin: &signer,
    //     token_uris: vector<String>,
    // ) acquires NFTMintConfig, CollectionConfig {
    //     let nft_mint_config = borrow_global_mut<NFTMintConfig>(@gen2_mint);
    //     assert!(signer::address_of(admin) == nft_mint_config.admin, error::permission_denied(ENOT_AUTHORIZED));

    //     assert!(exists<CollectionConfig>(@gen2_mint), error::permission_denied(ECONFIG_NOT_INITIALIZED));
        
    //     let collection_config = borrow_global_mut<CollectionConfig>(@gen2_mint);

    //     assert!(vector::length(&token_uris) + big_vector::length(&collection_config.tokens) <= collection_config.collection_maximum || collection_config.collection_maximum == 0, error::invalid_argument(EEXCEEDS_COLLECTION_MAXIMUM));

    //     let i = 0;
    //     while (i < vector::length(&token_uris)) {
    //         big_vector::push_back(&mut collection_config.tokens, TokenAsset {
    //             token_uri: *vector::borrow(&token_uris, i),
    //         });
    //         i = i + 1;
    //     };
    // }

    // ======================================================================
    //   private helper functions //
    // ======================================================================

    // fun mint_random(claimer: &signer, batch: String) acquires DestinationProbabilityConfig, PriceConfig {
    //     let claimer_addr = signer::address_of(claimer);

    //     let price = get_price_by_batch(batch);
    //     let probabilities = get_probabilities_by_batch(batch);

    //     // mint token to the receiver
    //     let resource_signer = create_signer_with_capability(&nft_mint_config.signer_cap);

    //     while (amount > 0) {
    //         let token_name = source_token.base_token_name;
    //         string::append_utf8(&mut token_name, b" #");
    //         let num = u64_to_string(source_token.largest_token_number);
    //         string::append(&mut token_name, num);
    //         token::create_token_script(
    //             &resource_signer,
    //             source_token.collection_name,
    //             token_name,
    //             source_token.token_description,
    //             1,
    //             1,
    //             source_token.token_uri,
    //             source_token.royalty_payee_address,
    //             source_token.royalty_points_den,
    //             source_token.royalty_points_num,
    //             TOKEN_MUTABILITY_CONFIG,
    //             vector<String>[utf8(BURNABLE_BY_OWNER)],
    //             vector<vector<u8>>[bcs::to_bytes<bool>(&true)],
    //             vector<String>[utf8(b"bool")],
    //         );
    //         let token_id = token::create_token_id_raw(
    //             signer::address_of(&resource_signer),
    //             source_token.collection_name,
    //             token_name,
    //             0
    //         );
    //         token::direct_transfer(&resource_signer, nft_claimer, token_id, 1);

    //         event::emit_event<MintingEvent>(
    //             &mut nft_mint_config.token_minting_events,
    //             MintingEvent {
    //                 token_receiver_address: receiver_addr,
    //                 token_id,
    //             }
    //         );

    //         source_token.largest_token_number = source_token.largest_token_number + 1;
    //         amount = amount - 1;
    //     };
    // }

    fun u64_to_string(value: u64): String {
        if (value == 0) {
            return utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        utf8(buffer)
    }

    fun num_from_source_token_name(name: String): String {
        let ind = string::index_of(&name, &string::utf8(b"#"));
        string::sub_string(&name, ind + 1, string::length(&name))
    }

    /// helper function to calculate the sum of a vector
    fun sum(v: &vector<u64>): u64 {
        let sum = 0;
        let i = 0;
        while (i < vector::length(v)) {
            sum = sum + *vector::borrow(v, i);
            i = i + 1;
        };
        return sum
    }

    fun get_price_by_batch(batch: String): u64 acquires PriceConfig {
        let price_config = borrow_global_mut<PriceConfig>(@gen2_mint);

        if (batch == utf8(b"batch_1")) {
            price_config.batch_one
        } else if (batch == utf8(b"batch_2")) {
            price_config.batch_two
        } else if (batch == utf8(b"batch_3")) {
            price_config.batch_three
        } else {
            price_config.general
        }
    }

    fun get_probabilities_by_batch(batch: String): vector<u64> acquires DestinationProbabilityConfig {
        let probabilities_config = borrow_global_mut<DestinationProbabilityConfig>(@gen2_mint);

        if (batch == utf8(b"batch_1")) {
            probabilities_config.batch_one
        } else if (batch == utf8(b"batch_2")) {
            probabilities_config.batch_two
        } else if (batch == utf8(b"batch_3")) {
            probabilities_config.batch_three
        } else {
            probabilities_config.general
        }
    }

    fun get_random_token(probabilities: &vector<u64>): TokenAsset acquires TokenPool {
        let tier = get_random_pool_tier(probabilities);
        let pools = borrow_global_mut<TokenPool>(@gen2_mint);

        // This is basically the random number
        let now = timestamp::now_microseconds();

        if (tier == 0) {
            let index = now % big_vector::length(&pools.tier1_pool);
            big_vector::swap_remove(&mut pools.tier1_pool, index)
        } else if (tier == 1) {
            let index = now % big_vector::length(&pools.tier2_pool);
            big_vector::swap_remove(&mut pools.tier2_pool, index)
        } else if (tier == 2) {
            let index = now % big_vector::length(&pools.tier3_pool);
            big_vector::swap_remove(&mut pools.tier3_pool, index)
        } else {
            let index = now % big_vector::length(&pools.tier4_pool);
            big_vector::swap_remove(&mut pools.tier4_pool, index)
        }
    }

    /// This function will get us a non empty pool based on the probabilities config
    /// If a pool is empty, it will ignore the pool while still maintaining the correct probability ratios
    fun get_random_pool_tier(probabilities: &vector<u64>): u64 acquires TokenPool {
        let pools = borrow_global_mut<TokenPool>(@gen2_mint);
        let multiplier = vector::empty();
        vector::push_back(&mut multiplier, if (big_vector::length(&pools.tier1_pool) > 0) {
            1
        } else {
            0
        });
        vector::push_back(&mut multiplier, if (big_vector::length(&pools.tier2_pool) > 0) {
            1
        } else {
            0
        });
        vector::push_back(&mut multiplier, if (big_vector::length(&pools.tier3_pool) > 0) {
            1
        } else {
            0
        });
        vector::push_back(&mut multiplier, if (big_vector::length(&pools.tier4_pool) > 0) {
            1
        } else {
            0
        });
        let now = timestamp::now_microseconds();
        let total = 0;
        let i = 0;
        while (i < vector::length(probabilities)) {
            total = total + *vector::borrow(probabilities, i) * *vector::borrow(&multiplier, i);
            i = i + 1;
        };
        let random_bucket_perc = now % total;
        let running_sum = 0;
        let i = 0;
        while (i < vector::length(probabilities)) {
            running_sum = running_sum + *vector::borrow(probabilities, i) * *vector::borrow(&multiplier, i);
            // This will skip over empty pools
            if (running_sum >= random_bucket_perc) {
                break
            };
            i = i + 1;
        };
        i
    }
}
