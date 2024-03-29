module gen2_mint::minting {
    use std::error;
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::vector;
    use std::option;
    use std::bcs;
    use std::from_bcs;
    use std::hash;

    use aptos_framework::transaction_context;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::account::{Self, SignerCapability, create_signer_with_capability};
    use gen2_mint::big_vector::{Self, BigVector};
    use gen2_mint::bucket_table::{Self, BucketTable};
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_token_objects::property_map;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_token::token::{burn, create_token_data_id, get_tokendata_uri};
    use aptos_token_objects::royalty;
    use aptos_std::table::{Self, Table};

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
    /// Collection or token does not exist at address
    const ENOT_EXIST: u64 = 20;
    /// Only creator is authorized
    const ENOT_CREATOR: u64 = 20;
    /// Token asset needs to have 13 elements
    const ETOKEN_ASSET_WRONG_LENGTH: u64 = 21;
    /// Token asset already added before
    const ETOKEN_ASSET_ALREADY_ADDED: u64 = 22;
    /// Rarity needs to be one of Legendary, Epic, Rare, Common
    const ERARITY_NOT_RECOGNIZED: u64 = 23;

    /// Keys batch URIs
    const BATCH_ONE: vector<u8> = b"https://arweave.net/1ZLZpknqquhGJQE8amEqjBSOHFySUjJi-hgiJ-ayueU";
    const BATCH_TWO: vector<u8> = b"https://arweave.net/bEn-0ZO_gEUKkuR6puezQKT48vSyTdiLGDrOX0f2LOs";
    const BATCH_THREE: vector<u8> = b"https://arweave.net/jXdxJ4ZIMcNNI5i87-zJs0MMik_cOT1-NhaViz8oBKA";

    const KEYS_COLLECTION: vector<u8> = b"[REDACTED] Keys";

    const LEGENDARY: vector<u8> = b"Legendary";
    const EPIC: vector<u8> = b"Epic";
    const RARE: vector<u8> = b"Rare";
    const COMMON: vector<u8> = b"Common";

    /// WhitelistMintConfig stores information about whitelist minting.
    struct WhitelistMintConfig has key {
        whitelisted_address: BucketTable<address, u64>,
    }

    struct TokenPoolView {
        tier1_pool: u64,
        tier2_pool: u64,
        tier3_pool: u64,
        tier4_pool: u64,
    }

    struct TokenPool has key {
        tier1_pool: BigVector<TokenAsset>,
        tier2_pool: BigVector<TokenAsset>,
        tier3_pool: BigVector<TokenAsset>,
        tier4_pool: BigVector<TokenAsset>,
    }

    struct AllTokenAssets has key {
        all_token_assets: Table<String, String>
    }

    struct CreatorConfig has key {
        resource_signer_cap: SignerCapability,
        token_description: String,
        mint_payee_address: address,
        collection_description: String,
        collection_name: String,
        collection_uri: String,
        collection_supply: u64,
        royalty_address: address,
        royalty_denominator: u64,
        royalty_numerator: u64
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

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Gen2Collection has key {
        mutator_ref: collection::MutatorRef,
    }

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
        mint_events: event::EventHandle<MintEvent>,
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
        price: u64,
        rarity: String,
        token_uri: String,
        token_name: String,
    }

    fun init_module(admin: &signer) {
        // Construct a seed vector that pseudo-randomizes the resource address generated.
        let seed_vec = bcs::to_bytes(&timestamp::now_seconds());
        let (_, resource_signer_cap) = account::create_resource_account(admin, seed_vec);

        move_to(admin, CreatorConfig {
            resource_signer_cap,
            token_description: utf8(b""),
            mint_payee_address: signer::address_of(admin),
            collection_description: utf8(b""),
            collection_name: utf8(b""),
            collection_uri: utf8(b""),
            collection_supply: 0,
            royalty_address: signer::address_of(admin),
            royalty_denominator: 0,
            royalty_numerator: 0
        });
    }

    public entry fun set_creator_config(
        admin: &signer,
        token_description: String,
        mint_payee_address: address,
        collection_description: String,
        collection_name: String,
        collection_uri: String,
        collection_supply: u64,
        royalty_address: address,
        royalty_denominator: u64,
        royalty_numerator: u64
    ) acquires CreatorConfig {
        if (signer::address_of(admin) != @gen2_mint) {
            assert!(false, error::permission_denied(ENOT_AUTHORIZED)); 
        };

        let config = borrow_global_mut<CreatorConfig>(@gen2_mint);
        config.token_description = token_description;
        config.mint_payee_address = mint_payee_address;
        config.collection_description = collection_description;
        config.collection_name = collection_name;
        config.collection_uri = collection_uri;
        config.collection_supply = collection_supply;
        config.royalty_address = royalty_address;
        config.royalty_denominator = royalty_denominator;
        config.royalty_numerator = royalty_numerator;
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

    entry fun create_collection(
        admin: &signer
    ) acquires CreatorConfig {
        assert!(signer::address_of(admin) == @gen2_mint, error::permission_denied(ENOT_AUTHORIZED));

        let creator_config = borrow_global<CreatorConfig>(@gen2_mint);
        let royalty_config = royalty::create(
            creator_config.royalty_numerator,
            creator_config.royalty_denominator,
            creator_config.royalty_address
        );
        let creator = create_signer_with_capability(&creator_config.resource_signer_cap);

        // Creates the collection with unlimited supply and without establishing any royalty configuration.
        let constructor_ref = collection::create_fixed_collection(
            &creator,
            creator_config.collection_description,
            creator_config.collection_supply,
            creator_config.collection_name,
            option::some(royalty_config),
            creator_config.collection_uri,
        );
        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref = collection::generate_mutator_ref(&constructor_ref);
        move_to(&object_signer, Gen2Collection { mutator_ref });
    }

    entry fun set_collection_description(
        admin: &signer,
        collection: Object<Gen2Collection>,
        new_description: String
    ) acquires CreatorConfig, Gen2Collection {
        assert!(signer::address_of(admin) == @gen2_mint, error::permission_denied(ENOT_AUTHORIZED));
        let creator_config = borrow_global<CreatorConfig>(@gen2_mint);
        let creator = create_signer_with_capability(&creator_config.resource_signer_cap);
        authorize_creator(&creator, &collection);
        let collection_address = object::object_address(&collection);
        let collection_object = borrow_global<Gen2Collection>(collection_address);
        let mutator_ref = &collection_object.mutator_ref;
        collection::set_description(
            mutator_ref,
            new_description,
        );
    }

    entry fun set_collection_uri(
        admin: &signer,
        collection: Object<Gen2Collection>,
        new_uri: String
    ) acquires CreatorConfig, Gen2Collection {
        assert!(signer::address_of(admin) == @gen2_mint, error::permission_denied(ENOT_AUTHORIZED));
        let creator_config = borrow_global<CreatorConfig>(@gen2_mint);
        let creator = create_signer_with_capability(&creator_config.resource_signer_cap);
        authorize_creator(&creator, &collection);
        let collection_address = object::object_address(&collection);
        let collection_object = borrow_global<Gen2Collection>(collection_address);
        let mutator_ref = &collection_object.mutator_ref;
        collection::set_uri(
            mutator_ref,
            new_uri,
        );
    }

    #[view]
    public fun view_pool_length(): TokenPoolView acquires TokenPool {
        let pool = borrow_global<TokenPool>(@gen2_mint);
        TokenPoolView {
            tier1_pool: big_vector::length(&pool.tier1_pool),
            tier2_pool: big_vector::length(&pool.tier2_pool),
            tier3_pool: big_vector::length(&pool.tier3_pool),
            tier4_pool: big_vector::length(&pool.tier4_pool),
        }
    }

    #[view]
    public fun view_wl_status(addr: address): u64 acquires WhitelistMintConfig {
        let whitelist_config = borrow_global_mut<WhitelistMintConfig>(@gen2_mint);
        if(!bucket_table::contains(&whitelist_config.whitelisted_address, &addr)) {
            0
        } else {
            *bucket_table::borrow(&mut whitelist_config.whitelisted_address, addr)
        }
    }

    /// Burn 1 or more keys to mint a gen2 token
    entry fun burn_keys_to_mint(
        claimer: &signer,
        keys_to_burn: vector<String>,
    ) acquires CreatorConfig, DestinationProbabilityConfig, Gen2Token, PriceConfig, TokenPool {
        let i = 0;
        while (i < vector::length(&keys_to_burn)) {
            let key_to_burn = *vector::borrow(&keys_to_burn, i);
            burn_key_to_mint_internal(claimer, key_to_burn, i);
            i = i + 1;
        }
    }

    /// Do not burn keys to mint a gen2 token
    entry fun wl_mint(
        claimer: &signer,
        minting_amount: u64,
    ) acquires CreatorConfig, DestinationProbabilityConfig, Gen2Token, PriceConfig, TokenPool, WhitelistMintConfig {
        let whitelist_mint_config = borrow_global_mut<WhitelistMintConfig>(@gen2_mint);
        let claimer_address = signer::address_of(claimer);
        assert!(
            bucket_table::contains(&whitelist_mint_config.whitelisted_address, &claimer_address),
            error::permission_denied(EACCOUNT_NOT_WHITELISTED)
        );
        let remaining_minting_amount = bucket_table::borrow_mut(&mut whitelist_mint_config.whitelisted_address, claimer_address);
        assert!(*remaining_minting_amount >= minting_amount, error::invalid_argument(EAMOUNT_EXCEEDS_MINTS_ALLOWED));
        *remaining_minting_amount = *remaining_minting_amount - minting_amount;
        let i = 0;
        while (i < minting_amount) {
            mint_internal(claimer, utf8(b"general"), i);
            i = i + 1;
        }
    }

    /// Add user addresses to the whitelist for the keys collection
    public entry fun add_to_whitelist(
        admin: &signer,
        wl_addresses: vector<address>,
        mint_limit: u64
    ) acquires WhitelistMintConfig {
        assert!(signer::address_of(admin) == @gen2_mint, error::permission_denied(ENOT_AUTHORIZED));
        if (!exists<WhitelistMintConfig>(@gen2_mint)) {
            move_to(admin, WhitelistMintConfig {
                whitelisted_address: bucket_table::new<address, u64>(100),
            });
        };
        let whitelist_mint_config = borrow_global_mut<WhitelistMintConfig>(@gen2_mint);

        let i = 0;
        while (i < vector::length(&wl_addresses)) {
            let addr = *vector::borrow(&wl_addresses, i);
            // assert that the specified address exists
            assert!(account::exists_at(addr), error::invalid_argument(EACCOUNT_DOES_NOT_EXIST));
            bucket_table::add(&mut whitelist_mint_config.whitelisted_address, addr, mint_limit);
            i = i + 1;
        };
    }

    /// add tokens to a particular pool
    public entry fun add_tokens(
        admin: &signer,
        token_assets: vector<vector<String>>,
    ) acquires AllTokenAssets, TokenPool {
        assert!(signer::address_of(admin) == @gen2_mint, error::permission_denied(ENOT_AUTHORIZED));
        if (!exists<AllTokenAssets>(@gen2_mint)) {
            move_to(admin, AllTokenAssets {
                all_token_assets: table::new(),
            });
        };
        if (!exists<TokenPool>(@gen2_mint)) {
            move_to(admin, TokenPool {
                tier1_pool: big_vector::empty<TokenAsset>(128),
                tier2_pool: big_vector::empty<TokenAsset>(128),
                tier3_pool: big_vector::empty<TokenAsset>(128),
                tier4_pool: big_vector::empty<TokenAsset>(128),
            });
        };
        let all_assets = &mut borrow_global_mut<AllTokenAssets>(@gen2_mint).all_token_assets;
        let pool_config = borrow_global_mut<TokenPool>(@gen2_mint);

        let i = 0;
        while (i < vector::length(&token_assets)) {
            let token_asset = *vector::borrow(&token_assets, i);
            assert!(vector::length(&token_asset) == 13, error::invalid_argument(ETOKEN_ASSET_WRONG_LENGTH));
            let name = *vector::borrow(&token_asset, 1);
            assert!(!table::contains(all_assets, name), error::invalid_argument(ETOKEN_ASSET_ALREADY_ADDED));
            let rarity = *vector::borrow(&token_asset, 2);
            assert!(rarity == utf8(LEGENDARY)
                || rarity == utf8(EPIC)
                || rarity == utf8(RARE)
                || rarity == utf8(COMMON)
            , error::invalid_argument(ERARITY_NOT_RECOGNIZED));
            let pool = if (rarity == utf8(LEGENDARY)) {
                &mut pool_config.tier1_pool
            } else if (rarity == utf8(EPIC)) {
                &mut pool_config.tier2_pool
            } else if (rarity == utf8(RARE)) {
                &mut pool_config.tier3_pool
            } else {
                &mut pool_config.tier4_pool
            };

            table::add(all_assets, name, rarity);
            big_vector::push_back(pool, TokenAsset {
                token_uri: *vector::borrow(&token_asset, 0),
                token_name: name,
                rarity: rarity,
                beak: *vector::borrow(&token_asset, 3),
                eyes: *vector::borrow(&token_asset, 4),
                base: *vector::borrow(&token_asset, 5),
                patterns: *vector::borrow(&token_asset, 6),
                hair: *vector::borrow(&token_asset, 7),
                neck: *vector::borrow(&token_asset, 8),
                clothes: *vector::borrow(&token_asset, 9),
                body: *vector::borrow(&token_asset, 10),
                earring: *vector::borrow(&token_asset, 11),
                background: *vector::borrow(&token_asset, 12),
            });
            i = i + 1;
        }
    }

    // ======================================================================
    //   private helper functions //
    // ======================================================================

    fun burn_key_to_mint_internal(
        claimer: &signer,
        key_to_burn: String,
        nonce: u64,
    ) acquires CreatorConfig, DestinationProbabilityConfig, Gen2Token, PriceConfig, TokenPool {
        // Try to burn a key
        let batch = burn_key(claimer, key_to_burn);
        mint_internal(claimer, batch, nonce);
    }

    fun mint_internal(
        claimer: &signer,
        batch: String,
        nonce: u64,
    ) acquires CreatorConfig, DestinationProbabilityConfig, Gen2Token, PriceConfig, TokenPool {
        let creator_config = borrow_global<CreatorConfig>(@gen2_mint);
        let price = get_price_by_batch(batch);
        coin::transfer<AptosCoin>(claimer, creator_config.mint_payee_address, price);
        let (token_asset, token_address) = mint_random(claimer, batch, nonce);
        event::emit_event(
            &mut borrow_global_mut<Gen2Token>(token_address).mint_events,
            MintEvent {
                token_receiver_address: signer::address_of(claimer),
                token_data_id: token_address,
                price,
                rarity: token_asset.rarity,
                token_uri: token_asset.token_uri,
                token_name: token_asset.token_name,
            }
        )
    }

    /// Authorizes the creator of the token or collection. Asserts that the token exists and the creator of the token
    /// is `creator`.
    inline fun authorize_creator<T: key>(creator: &signer, object: &Object<T>) {
        let object_address = object::object_address(object);
        assert!(
            exists<T>(object_address),
            error::not_found(ENOT_EXIST),
        );
        assert!(
            token::creator(*object) == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR),
        );
    }

    /// Mint the token given batch
    /// Returns token asset upon successful mint to display in the UI
    fun mint_random(
        claimer: &signer,
        batch: String,
        nonce: u64,
    ): (TokenAsset, address) acquires CreatorConfig, DestinationProbabilityConfig, TokenPool {
        let claimer_addr = signer::address_of(claimer);

        let probabilities = get_probabilities_by_batch(batch);
        let token_asset = get_random_token_asset(&probabilities, nonce);

        // Mint the token
        let creator_config = borrow_global<CreatorConfig>(@gen2_mint);
        let creator = create_signer_with_capability(&creator_config.resource_signer_cap);
        let description = creator_config.token_description;

        let constructor_ref = token::create_named_token(
            &creator,
            creator_config.collection_name,
            description,
            token_asset.token_name,
            option::none(),
            token_asset.token_uri,
        );

        // Generates the object signer and the refs. The object signer is used to publish a resource
        let object_signer = object::generate_signer(&constructor_ref);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref);

        // Transfers the token to the `claimer` address
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, claimer_addr);

        // Add the traits to the object
        let mask_traits = MaskTraits {
            rarity: token_asset.rarity,
            beak: token_asset.beak,
            eyes: token_asset.eyes,
            base: token_asset.base,
            patterns: token_asset.patterns,
        };
        let person_traits = PersonTraits {
            hair: token_asset.hair,
            neck: token_asset.neck,
            clothes: token_asset.clothes,
            body: token_asset.body,
            earring: token_asset.earring,
            background: token_asset.background,
        };

        // Initialize the property map for display
        let properties = property_map::prepare_input(vector[], vector[], vector[]);
        property_map::init(&constructor_ref, properties);
        add_mask_traits_to_property_map(&property_mutator_ref, &mask_traits);
        add_person_traits_to_property_map(&property_mutator_ref, &person_traits);
        
        move_to(&object_signer, mask_traits);
        move_to(&object_signer, person_traits);

        // Move the object metadata to the object
        let gen2_token = Gen2Token {
            burn_ref,
            transfer_ref,
            mutator_ref,
            property_mutator_ref,
            mint_events: object::new_event_handle(&object_signer),
        };
        move_to(&object_signer, gen2_token);

        (token_asset, signer::address_of(&object_signer))
    }

    /// Burn the key and return the batch
    fun burn_key(
        claimer: &signer,
        key_name: String
    ): String {
        let token_data_id = create_token_data_id(@keys_addr, utf8(KEYS_COLLECTION), key_name);
        let batch = get_batch_from_uri(get_tokendata_uri(@keys_addr, token_data_id));
        // Burn the key
        burn(claimer, @keys_addr, utf8(KEYS_COLLECTION), key_name, 0, 1);
        batch
    }

    fun get_batch_from_uri(
        uri: String
    ): String {
        let batch = utf8(b"");
        if (uri == utf8(BATCH_ONE)) {
            batch = utf8(b"batch_1");
        } else if (uri == utf8(BATCH_TWO)) {
            batch = utf8(b"batch_2");
        } else if (uri == utf8(BATCH_THREE)) {
            batch = utf8(b"batch_3");
        } else {
            assert!(false, error::invalid_argument(EBATCH_NOT_FOUND));
        };
        
        batch
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

    fun get_random_token_asset(probabilities: &vector<u64>, nonce: u64): TokenAsset acquires TokenPool {
        let tier = get_random_pool_tier(probabilities, nonce);
        let pools = borrow_global_mut<TokenPool>(@gen2_mint);

        if (tier == 0) {
            let index = random_with_nonce(big_vector::length(&pools.tier1_pool), nonce);
            big_vector::swap_remove(&mut pools.tier1_pool, index)
        } else if (tier == 1) {
            let index = random_with_nonce(big_vector::length(&pools.tier2_pool), nonce);
            big_vector::swap_remove(&mut pools.tier2_pool, index)
        } else if (tier == 2) {
            let index = random_with_nonce(big_vector::length(&pools.tier3_pool), nonce);
            big_vector::swap_remove(&mut pools.tier3_pool, index)
        } else {
            let index = random_with_nonce(big_vector::length(&pools.tier4_pool), nonce);
            big_vector::swap_remove(&mut pools.tier4_pool, index)
        }
    }

    /// This function will get us a non empty pool based on the probabilities config
    /// If a pool is empty, it will ignore the pool while still maintaining the correct probability ratios
    fun get_random_pool_tier(probabilities: &vector<u64>, nonce: u64): u64 acquires TokenPool {
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
        let total = 0;
        let i = 0;
        while (i < vector::length(probabilities)) {
            total = total + *vector::borrow(probabilities, i) * *vector::borrow(&multiplier, i);
            i = i + 1;
        };
        let random_bucket_perc = random_with_nonce(total, nonce);
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

    public fun random_with_nonce(max: u64, nonce: u64): u64
    {                        
        let number = timestamp::now_microseconds();
        let script_hash: vector<u8> = transaction_context::get_script_hash();
        let x = bcs::to_bytes<u64>(&number);
        let y = bcs::to_bytes<u64>(&nonce);
        vector::append(&mut x, script_hash);           
        vector::append(&mut x, y);
        let tmp = hash::sha2_256(x);

        let data = vector<u8>[];
        let i = 24;
        while (i < 32)
        {
            let x =vector::borrow(&tmp, i);
            vector::append(&mut data,vector<u8>[*x]);
            i= i + 1;
        };
        let random = from_bcs::to_u64(data) % max;
        random
    }

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
        let ind = string::index_of(&name, &utf8(b"#"));
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

    fun add_mask_traits_to_property_map(
        mutator_ref: &property_map::MutatorRef,
        mask_traits: &MaskTraits
    ) {
        property_map::add_typed(
            mutator_ref,
            utf8(b"Rarity"),
            mask_traits.rarity,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Beak"),
            mask_traits.beak,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Eyes"),
            mask_traits.eyes,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Base"),
            mask_traits.base,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Patterns"),
            mask_traits.patterns,
        );
    }

    fun add_person_traits_to_property_map(
        mutator_ref: &property_map::MutatorRef,
        person_traits: &PersonTraits
    ) {
        property_map::add_typed(
            mutator_ref,
            utf8(b"Hair"),
            person_traits.hair,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Neck"),
            person_traits.neck,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Clothes"),
            person_traits.clothes,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Body"),
            person_traits.body,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Earring"),
            person_traits.earring,
        );
        property_map::add_typed(
            mutator_ref,
            utf8(b"Background"),
            person_traits.background,
        );
    }
}
