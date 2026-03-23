import XCTest
@testable import WalletCore

final class WalletCoreTests: XCTestCase {
    private let verifier = DeterministicSignatureVerifier()

    func testLockTransitionMovesWalletToLockedState() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 4, lifecycleState: .active)

        let transition = try stateMachine.transition(from: initialState, event: .lock)

        XCTAssertEqual(transition.previousState.lifecycleState, .active)
        XCTAssertEqual(transition.nextState.lifecycleState, .locked)
        XCTAssertEqual(transition.nextState.balance, 100)
        XCTAssertEqual(transition.nextState.nextExpectedNonce, 4)
    }

    func testUnlockTransitionMovesWalletToActiveState() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 4, lifecycleState: .locked)

        let transition = try stateMachine.transition(from: initialState, event: .unlock)

        XCTAssertEqual(transition.previousState.lifecycleState, .locked)
        XCTAssertEqual(transition.nextState.lifecycleState, .active)
        XCTAssertEqual(transition.nextState.balance, 100)
        XCTAssertEqual(transition.nextState.nextExpectedNonce, 4)
    }

    func testSuccessfulTransactionApplication() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 4)
        let transaction = makeSignedTransaction(
            id: "trscn-success",
            from: "alex",
            to: "bob",
            amount: 30,
            nonce: 4,
            stateMachine: stateMachine
        )

        let transition = try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))

        XCTAssertEqual(transition.previousState, initialState)
        XCTAssertEqual(transition.nextState.balance, 70)
        XCTAssertEqual(transition.nextState.nextExpectedNonce, 5)
        XCTAssertEqual(transition.nextState.appliedTransactionIDs, Set(["trscn-success"]))
        XCTAssertEqual(transition.nextState.lifecycleState, .active)
    }

    func testInsufficientBalanceFails() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 20, nextExpectedNonce: 1)
        let transaction = makeSignedTransaction(
            id: "trscn-low-balance",
            from: "alex",
            to: "bob",
            amount: 21,
            nonce: 1,
            stateMachine: stateMachine
        )

        XCTAssertThrowsError(try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))) { error in
            XCTAssertEqual(error as? WalletError, WalletError.insufficientBalance(available: 20, requested: 21))
        }
    }

    func testInvalidNonceFails() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 3)
        let transaction = makeSignedTransaction(
            id: "trscn-bad-nonce",
            from: "alex",
            to: "bob",
            amount: 20,
            nonce: 2,
            stateMachine: stateMachine
        )

        XCTAssertThrowsError(try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))) { error in
            XCTAssertEqual(error as? WalletError, WalletError.invalidNonce(expected: 3, received: 2))
        }
    }

    func testDuplicateTransactionFails() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(
            walletID: "alex",
            balance: 100,
            nextExpectedNonce: 5,
            appliedTransactionIDs: ["trscn-duplicate"]
        )
        let transaction = makeSignedTransaction(
            id: "trscn-duplicate",
            from: "alex",
            to: "bob",
            amount: 20,
            nonce: 5,
            stateMachine: stateMachine
        )

        XCTAssertThrowsError(try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))) { error in
            XCTAssertEqual(error as? WalletError, WalletError.duplicateTransaction(id: "trscn-duplicate"))
        }
    }

    func testInvalidSignatureFails() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 0)
        let transaction = TransactionProposal(
            id: "trscn-invalid-signature",
            from: "alex",
            to: "bob",
            amount: 10,
            nonce: 0,
            signature: "invalid-signature"
        )

        XCTAssertThrowsError(try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))) { error in
            XCTAssertEqual(error as? WalletError, WalletError.invalidSignature)
        }
    }

    func testWalletLockedFails() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(
            walletID: "alex",
            balance: 100,
            nextExpectedNonce: 0,
            lifecycleState: .locked
        )
        let transaction = makeSignedTransaction(
            id: "trscn-locked",
            from: "alex",
            to: "bob",
            amount: 10,
            nonce: 0,
            stateMachine: stateMachine
        )

        XCTAssertThrowsError(try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))) { error in
            XCTAssertEqual(error as? WalletError, WalletError.walletLocked)
        }
    }

    func testSelfTransferAttemptFails() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 0)
        let transaction = makeSignedTransaction(
            id: "trscn-self",
            from: "alex",
            to: "alex",
            amount: 10,
            nonce: 0,
            stateMachine: stateMachine
        )

        XCTAssertThrowsError(try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))) { error in
            XCTAssertEqual(error as? WalletError, WalletError.selfTransferAttempt)
        }
    }

    func testUnsupportedSenderFails() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 0)
        let transaction = makeSignedTransaction(
            id: "trscn-foreign-sender",
            from: "mallory",
            to: "bob",
            amount: 10,
            nonce: 0,
            stateMachine: stateMachine
        )

        XCTAssertThrowsError(try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))) { error in
            XCTAssertEqual(
                error as? WalletError,
                WalletError.unsupportedSender(expected: "alex", received: "mallory")
            )
        }
    }

    func testInvalidAmountFails() throws {
        let stateMachine = WalletStateMachine(verifier: verifier)
        let initialState = WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 0)
        let transaction = makeSignedTransaction(
            id: "trscn-zero-amount",
            from: "alex",
            to: "bob",
            amount: 0,
            nonce: 0,
            stateMachine: stateMachine
        )

        XCTAssertThrowsError(try stateMachine.transition(from: initialState, event: .applyTransaction(transaction))) { error in
            XCTAssertEqual(error as? WalletError, WalletError.invalidAmount)
        }
    }

    func testActorProtectsStateAcrossSequentialCalls() async throws {
        let wallet = WalletActor(
            initialState: WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 0),
            verifier: verifier
        )
        let stateMachine = WalletStateMachine(verifier: verifier)
        let first = makeSignedTransaction(
            id: "trscn-1",
            from: "alex",
            to: "bob",
            amount: 10,
            nonce: 0,
            stateMachine: stateMachine
        )
        let second = makeSignedTransaction(
            id: "trscn-2",
            from: "alex",
            to: "carol",
            amount: 15,
            nonce: 1,
            stateMachine: stateMachine
        )

        _ = try await wallet.apply(first)
        _ = try await wallet.apply(second)

        let snapshot = await wallet.snapshot()
        XCTAssertEqual(snapshot.balance, 75)
        XCTAssertEqual(snapshot.nextExpectedNonce, 2)
        XCTAssertEqual(snapshot.appliedTransactionIDs, Set(["trscn-1", "trscn-2"]))
    }

    func testActorRejectsConcurrentReplayAttempt() async throws {
        func applyResult(_ transaction: TransactionProposal, using wallet: WalletActor) async -> Result<WalletTransition, Error> {
            do {
                return .success(try await wallet.apply(transaction))
            } catch {
                return .failure(error)
            }
        }

        let wallet = WalletActor(
            initialState: WalletState(walletID: "alex", balance: 100, nextExpectedNonce: 0),
            verifier: verifier
        )
        let stateMachine = WalletStateMachine(verifier: verifier)
        let transaction = makeSignedTransaction(
            id: "trscn-replay",
            from: "alex",
            to: "bob",
            amount: 10,
            nonce: 0,
            stateMachine: stateMachine
        )

        async let firstResult: Result<WalletTransition, Error> = applyResult(transaction, using: wallet)
        async let secondResult: Result<WalletTransition, Error> = applyResult(transaction, using: wallet)

        let result1 = await firstResult
        let result2 = await secondResult
        let results = [result1, result2]
        let successes = results.compactMap { try? $0.get() }
        let failures = results.compactMap { result -> WalletError? in
            guard case let .failure(error) = result else { return nil }
            return error as? WalletError
        }

        XCTAssertEqual(successes.count, 1)
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures.contains(.duplicateTransaction(id: "trscn-replay")) || failures.contains(.invalidNonce(expected: 1, received: 0)))
    }

    private func makeSignedTransaction(
        id: String,
        from: String,
        to: String,
        amount: Amount,
        nonce: UInt64,
        stateMachine: WalletStateMachine
    ) -> TransactionProposal {
        let unsigned = TransactionProposal(
            id: id,
            from: from,
            to: to,
            amount: amount,
            nonce: nonce,
            signature: ""
        )
        let message = stateMachine.canonicalMessage(for: unsigned)
        let signature = DeterministicSignatureVerifier.sign(signer: from, message: message)
        return TransactionProposal(
            id: id,
            from: from,
            to: to,
            amount: amount,
            nonce: nonce,
            signature: signature
        )
    }
}
