# WalletAssignment

`WalletAssignment` is a small Swift package that models a wallet as a deterministic state machine with explicit validation, explicit failures, and a replaceable signature verification boundary. The package is intentionally biased toward correctness, predictability, and integration-readiness rather than UI or infrastructure concerns.

## Requirements

- Swift 6.2+
- macOS 13+

## How to run

Run the CLI demo:

```bash
swift run WalletAssignment
```

Run the test suite:

```bash
swift test
```

## Architecture

The package is split into two targets with distinct responsibilities:

- `WalletCore`: pure domain logic, state transitions, validation rules, and the signature verification abstraction.
- `WalletAssignment`: a tiny executable target that demonstrates how the core could be driven by an app layer, SDK adapter, or integration harness.

Key design choices:

- Wallet logic is modeled as a deterministic state machine: `WalletState + WalletEvent -> WalletTransition | WalletError`.
- `WalletStateMachine` is synchronous and side-effect free from the perspective of state mutation, which keeps transitions explicit and testable.
- Signature verification is isolated behind `SignatureVerifying`, so the verification strategy can be swapped without changing business rules.
- `WalletActor` is intentionally kept outside the core rules engine and acts as a concurrency boundary for consumers that need shared mutable access. All wallet events, including `lock` and `unlock`, are delegated back into `WalletStateMachine` so the transition rules stay centralized.

This separation is meant to reflect how a mobile wallet often evolves in practice: deterministic business rules in one layer, SDK or FFI-backed verification in another, and app-facing orchestration on top.

## Determinism

The module is designed to keep state updates deterministic for the same input state and proposal:

- balances use integer units (`UInt64`) rather than floating-point values
- the signed payload is constructed through a stable canonical message format
- validation runs in a fixed order
- successful transitions return a new immutable state rather than mutating shared state in place

That makes behavior easier to reason about, test, and eventually delegate to a lower-level SDK while preserving predictable wallet semantics.

## Assumptions

- The wallet manages outgoing transfers for a single wallet identifier.
- Balances are represented as integer units (`UInt64`) to avoid floating-point ambiguity.
- Nonces are strictly sequential and must exactly match `nextExpectedNonce`.
- Transaction IDs are unique for each successfully applied transfer.
- Self-transfer and zero-value transfers are rejected as invalid proposals.
- A locked wallet rejects transaction application until explicitly unlocked.
- Only transactions originating from the wallet's own identifier are supported by this module.
- Duplicate id detection uses a bounded in-memory history of recent applied transaction ids rather than an unbounded container.

## Error handling

The module exposes explicit domain failures through `WalletError`:

- `insufficientBalance`
- `invalidNonce`
- `duplicateTransaction`
- `invalidSignature`
- `walletLocked`
- `selfTransferAttempt`
- `invalidAmount`
- `unsupportedSender`

No silent failures are used. Invalid operations always return a deterministic error.

Validation order is also deliberate. Sender identity, self-transfer, duplicate detection, nonce validation, balance checks, and signature verification are evaluated in a stable order so that the same invalid proposal fails the same way for the same input state. The duplicate id check is intentional: it serves as explicit replay detection on top of the strictly sequential nonce, rather than relying on nonce mismatch alone to describe every replay scenario.

## Concurrency considerations

If multiple transactions were applied concurrently against shared mutable wallet state without coordination, the system could suffer from:

- lost updates
- nonce races
- duplicate application of the same transaction
- non-deterministic balance mutations

The core state machine intentionally remains synchronous and deterministic. In a real app or SDK integration, mutation should be serialized behind an isolation boundary such as:

- a Swift `actor`
- a dedicated serial executor or queue
- a storage transaction boundary if persisted state is involved

This package includes `WalletActor` to demonstrate that pattern while keeping synchronization separate from domain rules.

## SDK / FFI considerations

If signature verification were delegated to a Rust SDK via FFI, important concerns would include:

- clear ownership rules for strings, buffers, and returned handles
- thread-safety guarantees of the Rust verifier
- deterministic error translation from Rust error enums into Swift `WalletError` or adapter-layer errors
- avoiding hidden global state inside the SDK
- stable canonical message encoding across language boundaries

The current `SignatureVerifying` protocol is designed so that an FFI adapter can be introduced without modifying the wallet state machine or its tests.

## Example usage

At a high level, usage looks like this:

```swift
let verifier = DeterministicSignatureVerifier()
let wallet = WalletActor(
    initialState: WalletState(walletID: "AlexWallet", balance: 150, nextExpectedNonce: 7),
    verifier: verifier
)

let transaction = TransactionProposal(
    id: "trscn-001",
    from: "AlexWallet",
    to: "MerchantWallet",
    amount: 40,
    nonce: 7,
    signature: "..."
)

let transition = try await wallet.apply(transaction)
print(transition.nextState)
```

See [`Sources/WalletAssignment/WalletAssignmentDemo.swift`](/Users/organicsoft/Desktop/WalletAssignment/Sources/WalletAssignment/WalletAssignmentDemo.swift) for a fuller demonstration.

## Tests covered

The test suite covers:

- lock transition
- unlock transition
- successful transaction application
- insufficient balance
- invalid nonce
- duplicate transaction
- invalid signature
- wallet locked
- self-transfer attempt
- unsupported sender
- invalid amount
- actor-based serialization example for concurrent calls
- explicit replay detection on the pure state machine
- concurrent replay behavior against the actor boundary
