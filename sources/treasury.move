module iota_ownership_workshop::treasury {
    use iota::iota::IOTA;
    use iota::balance::{Self, Balance};
    use iota::coin::{Self, Coin};
    
    // A unique capability object that grants administrative privileges. Witness pattern / capability pattern.
    // see https://docs.iota.org/developer/iota-101/move-overview/patterns/witness
    public struct AdminCap has key, store {
        id: UID,
    }

    // The Treasury object holds the pooled funds.
    public struct Treasury has key, store {
        id: UID,
        balance: Balance<IOTA>,
    }

    // Init function is a special function that is called when the module is created. 
    // Only executed once, transfer the AdminCap to the creator.
    fun init(ctx: &mut TxContext) {
        let cap = AdminCap { id: object::new(ctx) };
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    // Creates a new, shared Treasury object. Only the address with AdminCap can call this function.
    public entry fun create_treasury(
        _cap: &AdminCap,
        ctx: &mut TxContext
    ) {
        // See https://docs.iota.org/developer/iota-101/objects/shared-owned
        // Only newly created objects in the same transaction can be shared, in order to prevent developers' oversights.
        // One must explicitly use public_share_object, to share the object that is already created.
        let treasury_object = Treasury {
            id: object::new(ctx),
            balance: balance::zero(),
        };
        transfer::share_object(treasury_object);
    }

    // Allows anyone to deposit IOTA funds into a given Treasury.
    // The idea of Linear Type comes from linear logic: https://en.wikipedia.org/wiki/Substructural_type_system#Linear_type_systems
    // Where we want to make on-chain assets(coins and tokens) linear in Move in order to prevent the loss of funds.
    // By Linear, we mean there's no drop and no copy for the type of asset.
    // Therefore, we use balances and coins separately, only "committing" the balance back to the coin when manipulation's finished.
    public entry fun deposit(treasury: &mut Treasury, coin: Coin<IOTA>) {
        balance::join(&mut treasury.balance, coin::into_balance(coin));
    }

    // Allows the holder of the `AdminCap` to withdraw IOTA funds from the treasury.
    public entry fun withdraw(
        treasury: &mut Treasury,
        _cap: &AdminCap,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // split the balance of the treasury into the amount to withdraw and the amount to keep.
        // balance::split returns the 2nd input value, which is the amount to withdraw.
        // the treasury.balance is also reduced by the same amount in the function.
        let amount_to_withdraw = balance::split(&mut treasury.balance, amount);
        let coin_to_transfer = coin::from_balance(amount_to_withdraw, ctx);
        // The difference between public_transfer and transfer, refer to this discussion: 
        // https://forums.sui.io/t/what-is-the-underlying-difference-between-transfer-public-transfer-and-transfer-transfer/45403
        // https://docs.iota.org/developer/iota-101/objects/transfers/custom-rules
        // This is to ensure the enforced ownership model and design philosophy of Move.
        // One has to explicitly use public_transfer to transfer the object outside of its own module.
        transfer::public_transfer(coin_to_transfer, tx_context::sender(ctx));
    }
    
    // Returns the current balance of the Treasury.
    public fun balance(self: &Treasury): u64 {
        balance::value(&self.balance)
    }
    // This block is only compiled when running `iota-move test`.
    #[test_only]
    // This is the designated entry point for our test module.
    public fun test_init(ctx: &mut TxContext) {
        init(ctx)
    }

}