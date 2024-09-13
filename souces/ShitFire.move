module ShitFire::ShitNFT {
    use std::vector;
    use std::signer;
    use std::coin;
    use aptos_framework::token;
    use aptos_framework::event::{EventHandle, emit_event};

    struct MintInfo has drop {
        minter: address,
        token_id: u64,
    }

    struct ShitNFT has key {
        next_token_id: u64,
        owned_tokens: vector<u64>,
        mint_history: vector<MintInfo>,
        burned_tokens: vector<bool>,
        minters: vector<address>,
        has_minted: vector<bool>,
        token_minting_events: EventHandle<MintInfo>,
        airdrop_token: address,
        token_per_nft: u64,
        reward_token: address,
        reward_per_nft: u64,
    }

    public fun init(airdrop_token: address, token_per_nft: u64, reward_token: address, reward_per_nft: u64): ShitNFT {
        ShitNFT {
            next_token_id: 0,
            owned_tokens: vector::empty<u64>(),
            mint_history: vector::empty<MintInfo>(),
            burned_tokens: vector::empty<bool>(),
            minters: vector::empty<address>(),
            has_minted: vector::empty<bool>(),
            token_minting_events: account::new_event_handle<MintInfo>(&signer::address_of(signer::sender())),
            airdrop_token,
            token_per_nft,
            reward_token,
            reward_per_nft,
        }
    }

    entry fun withdraw_excess_tokens(nft: &mut ShitNFT, amount: u64) {
        assert!(signer::address_of(signer::sender()) == ShitNFT::address(), "Err: Only ShitNFT can call this function");
    }

    entry fun safe_mint(nft: &mut ShitNFT, to: address, uri: vector<u8>) {
        let token_id = nft.next_token_id;
        nft.next_token_id = token_id + 1;

        vector::push_back(&mut nft.owned_tokens, token_id);
        vector::push_back(&mut nft.mint_history, MintInfo { minter: signer::address_of(to), token_id });

        if !vector::contains(&nft.minters, signer::address_of(to)) {
            vector::push_back(&mut nft.minters, signer::address_of(to));
            vector::push_back(&mut nft.has_minted, true);
        }

        emit_event<MintInfo>(
            &mut nft.token_minting_events,
            MintInfo { minter: signer::address_of(to), token_id }
        );
    }

    entry fun transfer(nft: &mut ShitNFT, from: address, to: address, token_id: u64) {
        assert!(vector::contains(&nft.owned_tokens, token_id), "Err: Token does not exist");
        assert!(from == signer::address_of(signer::sender()), "Err: Only the owner can transfer the token");
        
        let index = vector::index_of(&nft.owned_tokens, token_id);
        vector::remove(&mut nft.owned_tokens, index);
        vector::push_back(&mut nft.owned_tokens, token_id);
    }

    entry fun airdrop_tokens(nft: &mut ShitNFT, owner: address) {
        let owned_nfts = get_nfts(nft, owner);
        assert!(vector::length(&owned_nfts) > 0, "You don't own any Shit NFTs");

        let total_airdrop_amount = 0;
        let total_reward_amount = vector::length(&owned_nfts) * nft.reward_per_nft;
        let eligible_minters = vector::empty<address>();
        let mut eligible_minters_count = 0;

        for (i in 0..vector::length(&owned_nfts)) {
            let minter = nft.mint_history[owned_nfts[i]].minter;
            let is_new_minter = !vector::contains(&eligible_minters, minter);
            if is_new_minter {
                vector::push_back(&mut eligible_minters, minter);
                eligible_minters_count += 1;
                total_airdrop_amount += nft.token_per_nft;
            }
        }

        assert!(token::balance_of(nft.airdrop_token, signer::address_of(signer::sender())) >= total_airdrop_amount, "Err: Insufficient airdrop token balance");
        assert!(token::balance_of(nft.reward_token, address(this)) >= total_reward_amount, "Err: Insufficient reward token balance in contract");

        for (i in 0..eligible_minters_count) {
            token::transfer_from(nft.airdrop_token, signer::address_of(signer::sender()), eligible_minters[i], nft.token_per_nft);
        }

        token::transfer(nft.reward_token, signer::address_of(signer::sender()), total_reward_amount);

        burn_all_nfts(nft, owner);
    }

    entry fun burn_all_nfts(nft: &mut ShitNFT, owner: address) {
        let token_ids = nft.owned_tokens;
        for token_id in token_ids {
            vector::push_back(&mut nft.burned_tokens, true);
        }
        nft.owned_tokens = vector::empty<u64>();
    }

    #[view]
    public fun get_nfts(nft: &ShitNFT, owner: address): vector<u64> {
        nft.owned_tokens
    }

    #[view]
    public fun get_mint_history(nft: &ShitNFT): vector<MintInfo> {
        nft.mint_history
    }

    #[view]
    public fun get_minters(nft: &ShitNFT): vector<address> {
        nft.minters
    }
}