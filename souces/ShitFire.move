module shit_nft_address::shit_nft {
    use std::string;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_token::token::{Self, TokenDataId, TokenId};
    use aptos_std::table::{Self, Table};

    /// Errors
    const ERROR_NOT_INITIALIZED: u64 = 1;
    const ERROR_ALREADY_INITIALIZED: u64 = 2;
    const ERROR_UNAUTHORIZED: u64 = 3;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 4;
    const ERROR_TRANSFER_BLOCKED: u64 = 5;

    /// Structs
    struct ShitNFTData has key {
        collection_name: string::String,
        token_data_id: TokenDataId,
        token_minted_count: u64,
        minters: vector<address>,
        minter_token_count: Table<address, u64>,
        mint_history: vector<MintInfo>,
        burned_tokens: Table<TokenId, bool>,
        airdrop_token: string::String,
        token_per_nft: u64,
        reward_token: string::String,
        reward_per_nft: u64,
    }

    struct MintInfo has store, drop {
        minter: address,
        token_id: TokenId,
    }

    public entry fun init(
        account: &signer,
        collection_name: string::String,
        airdrop_token: string::String,
        token_per_nft: u64,
        reward_token: string::String,
        reward_per_nft: u64
    ) {
        let addr = signer::address_of(account);
        assert!(!exists<ShitNFTData>(addr), ERROR_ALREADY_INITIALIZED);

        let collection_name_bytes = string::bytes(&collection_name);

        token::create_collection(
            account,
            collection_name,
            string::utf8(b"DragonShitNFT Collection"),
            string::utf8(b"Shit NFT for shit fire"),
            999999999, 
            vector<bool>[false, false, false]
        );

        let token_data_id = token::create_tokendata(
            account,
            collection_name,
            string::utf8(b"DragonShitNFT"),
            string::utf8(b"DragonShitNFT Token"),
            0,
            string::utf8(b"https://google.com/token"),
            addr, 
            100, 
            5,
            token::create_token_mutability_config(
                &vector<bool>[false, false, false, false, true]
            ),
            vector::empty<String>(),
            vector::empty<vector<u8>>(),
            vector::empty<String>()
        );

        move_to(account, ShitNFTData {
            collection_name,
            token_data_id,
            token_minted_count: 0,
            minters: vector::empty(),
            minter_token_count: table::new(),
            mint_history: vector::empty(),
            burned_tokens: table::new(),
            airdrop_token,
            token_per_nft,
            reward_token,
            reward_per_nft,
        });
    }

    /// mint a new ShitNFT
    public entry fun mint(account: &signer, to: address) acquires ShitNFTData {
        let addr = signer::address_of(account);
        assert!(exists<ShitNFTData>(addr), ERROR_NOT_INITIALIZED);

        let shit_nft_data = borrow_global_mut<ShitNFTData>(addr);
        let token_id = token::mint_token(
            account,
            shit_nft_data.collection_name,
            string::utf8(b"DragonShitNFT"),
            string::utf8(b"DragonShitNFT Token"),
            1,
        );

        if (to != addr) {
            token::direct_transfer(account, to, token_id, 1);
        }

        shit_nft_data.token_minted_count = shit_nft_data.token_minted_count + 1;

        let mint_info = MintInfo { minter: addr, token_id };
        vector::push_back(&mut shit_nft_data.mint_history, mint_info);

        if (!vector::contains(&shit_nft_data.minters, &addr)) {
            vector::push_back(&mut shit_nft_data.minters, addr);
        }

        let minter_count = table::borrow_mut_with_default(&mut shit_nft_data.minter_token_count, addr, 0);
        *minter_count = *minter_count + 1;
    }

    /// airdrop tokens based on owned ShitNFTs
    public entry fun airdrop_tokens(account: &signer) acquires ShitNFTData {
        let addr = signer::address_of(account);
        let shit_nft_data = borrow_global_mut<ShitNFTData>(@shit_nft_address);

        let owned_tokens = token::get_token_ids_with_balance(addr, shit_nft_data.collection_name);
        assert!(vector::length(&owned_tokens) > 0, ERROR_INSUFFICIENT_BALANCE);

        let total_airdrop_amount = 0u64;
        let total_reward_amount = (vector::length(&owned_tokens) as u64) * shit_nft_data.reward_per_nft;

        let eligible_minters = vector::empty<address>();

        let i = 0;
        while (i < vector::length(&owned_tokens)) {
            let token_id = vector::borrow(&owned_tokens, i);
            let mint_info = vector::borrow(&shit_nft_data.mint_history, i);
            let minter = mint_info.minter;

            if (!vector::contains(&eligible_minters, &minter)) {
                vector::push_back(&mut eligible_minters, minter);
                total_airdrop_amount = total_airdrop_amount + shit_nft_data.token_per_nft;
            }
            i = i + 1;
        };

        // transfer airdrop tokens
        let j = 0;
        while (j < vector::length(&eligible_minters)) {
            let minter = vector::borrow(&eligible_minters, j);
            coin::transfer<ShitNFTData>(account, *minter, shit_nft_data.token_per_nft);
            j = j + 1;
        };

        // transfer reward tokens
        coin::transfer<ShitNFTData>(@shit_nft_address, addr, total_reward_amount);

        // burn all ShitNFTs of the caller
        burn_all_shit_nfts(account);
    }

    /// internal function to burn all ShitNFTs owned by the caller
    fun burn_all_shit_nfts(account: &signer) acquires ShitNFTData {
        let addr = signer::address_of(account);
        let shit_nft_data = borrow_global_mut<ShitNFTData>(@shit_nft_address);

        let owned_tokens = token::get_token_ids_with_balance(addr, shit_nft_data.collection_name);

        let i = 0;
        while (i < vector::length(&owned_tokens)) {
            let token_id = vector::borrow(&owned_tokens, i);
            token::burn(account, shit_nft_data.collection_name, string::utf8(b"DragonShitNFT"), 0, 1);

            table::add(&mut shit_nft_data.burned_tokens, *token_id, true);

            let mint_info = vector::borrow(&shit_nft_data.mint_history, i);
            let minter = mint_info.minter;

            let minter_count = table::borrow_mut(&mut shit_nft_data.minter_token_count, minter);
            *minter_count = *minter_count - 1;

            if (*minter_count == 0) {
                remove_minter(minter);
            }

            i = i + 1;
        };
    }

    fun remove_minter(minter: address) acquires ShitNFTData {
        let shit_nft_data = borrow_global_mut<ShitNFTData>(@shit_nft_address);

        let (found, index) = vector::index_of(&shit_nft_data.minters, &minter);
        if (found) {
            vector::remove(&mut shit_nft_data.minters, index);
        };
    }

    public fun get_contract_reward_balance(): u64 acquires ShitNFTData {
        let shit_nft_data = borrow_global<ShitNFTData>(@shit_nft_address);
        coin::balance<ShitNFTData>(@shit_nft_address)
    }

    public entry fun withdraw_excess_reward_tokens(account: &signer, amount: u64) acquires ShitNFTData {
        let addr = signer::address_of(account);
        assert!(addr == @shit_nft_address, ERROR_UNAUTHORIZED);

        let contract_balance = coin::balance<ShitNFTData>(@shit_nft_address);
        assert!(contract_balance >= amount, ERROR_INSUFFICIENT_BALANCE);

        coin::transfer<ShitNFTData>(@shit_nft_address, addr, amount);
    }
}
