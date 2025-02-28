import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures that proposals can be created by members",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const user1 = accounts.get("wallet_1")!;

    let block = chain.mineBlock([
      Tx.contractCall(
        "dao-core",
        "create-proposal",
        [types.ascii("Test Proposal"), types.utf8("Description")],
        user1.address
      )
    ]);

    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectUint(1);
  },
});

Clarinet.test({
  name: "Ensures voting works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user1 = accounts.get("wallet_1")!;
    
    // Create proposal
    let block = chain.mineBlock([
      Tx.contractCall(
        "dao-core",
        "create-proposal",
        [types.ascii("Test Proposal"), types.utf8("Description")],
        user1.address
      )
    ]);

    // Vote on proposal
    block = chain.mineBlock([
      Tx.contractCall(
        "dao-core",
        "vote",
        [types.uint(1), types.bool(true)],
        user1.address
      )
    ]);

    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  },
});
