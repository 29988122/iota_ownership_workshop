// --- iota_ownership_workshop/tests/treasury_test.move ---

#[test_only]
module iota_ownership_workshop::treasury_test {
    use iota_ownership_workshop::treasury::{Self, AdminCap, Treasury};
    use iota::iota::IOTA;
    use iota::test_scenario::{Self, next_tx, take_from_sender, return_to_sender, take_shared, return_shared, end};
    use iota::coin;
    use iota::test_utils;

    // Pseudo addresses for testing.
    const ADMIN: address = @0xCAFE;
    const USER: address = @0xDEADBEEF;

    #[test]
    fun test_full_workflow() {
        // use scenario to simulate the transactions in testing without having to mock-deploy the module.
        let mut scenario = test_scenario::begin(ADMIN);

        // 1. First transaction: Emulate module initialization by ADMIN.
        {
            next_tx(&mut scenario, ADMIN);
            // transfer the AdminCap to the sender.
            // let cap = AdminCap { id: object::new(ctx) };
            // transfer::transfer(cap, tx_context::sender(ctx))
            // the above code are called in init function in treasury.move.
            treasury::test_init(test_scenario::ctx(&mut scenario));
        };
        
        // 2. Second transaction: Admin creates the Treasury.
        {
            next_tx(&mut scenario, ADMIN);
            // Take out the AdminCap from the sender to test the witness pattern on treasury.
            let cap = take_from_sender<AdminCap>(&scenario);
            treasury::new_treasury(&cap, test_scenario::ctx(&mut scenario));
            // return the AdminCap to the sender.
            return_to_sender(&scenario, cap);
        };

        // 3. Third transaction: User deposits funds.
        {
            // mint 1000 IOTA for testing.
            let coin = coin::mint_for_testing<IOTA>(1000, test_scenario::ctx(&mut scenario));
            next_tx(&mut scenario, USER);
            // retrieve the shared Treasury object we created in the previous transaction, from the scenario.
            let mut treasury = take_shared<Treasury>(&scenario);
            // deposit the IOTA to the treasury, as the user.
            treasury::deposit(&mut treasury, coin);
            // check the balance of the treasury to be 1000, the amount of IOTA we minted.
            test_utils::assert_eq(treasury::balance(&treasury), 1000);
            // return the shared Treasury object to the global inventory.
            return_shared(treasury);
        };

        // 4. Fourth transaction: Admin withdraws funds, permission control.
        {
            next_tx(&mut scenario, ADMIN);
            // objects must be taken out of the scenario/owner before being used.
            let mut treasury = take_shared<Treasury>(&scenario);
            let cap = take_from_sender<AdminCap>(&scenario);
            // 1000 - 700 should be 300, otherwise assert_eq will fail.
            treasury::withdraw(&cap, &mut treasury, 700, test_scenario::ctx(&mut scenario));
            test_utils::assert_eq(treasury::balance(&treasury), 300);
            // return the AdminCap to sender Admin, and the Treasury object to the global inventory.
            return_to_sender(&scenario, cap);
            return_shared(treasury);
        };

        end(scenario);
    }
}