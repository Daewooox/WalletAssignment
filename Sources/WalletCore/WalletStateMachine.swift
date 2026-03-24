import Foundation

public struct WalletStateMachine: Sendable {
    private let verifier: any SignatureVerifying

    public init(verifier: any SignatureVerifying) {
        self.verifier = verifier
    }

    public func transition(from state: WalletState, event: WalletEvent) throws -> WalletTransition {
        let nextState: WalletState

        switch event {
        case .lock:
            nextState = state.withLifecycleState(.locked)
        case .unlock:
            nextState = state.withLifecycleState(.active)
        case let .applyTransaction(transaction):
            nextState = try apply(transaction, to: state)
        }

        return WalletTransition(event: event, previousState: state, nextState: nextState)
    }

    public func canonicalMessage(for transaction: TransactionProposal) -> String {
        [
            "id=\(transaction.id)",
            "from=\(transaction.from)",
            "to=\(transaction.to)",
            "amount=\(transaction.amount)",
            "nonce=\(transaction.nonce)"
        ].joined(separator: "|")
    }

    private func apply(_ transaction: TransactionProposal, to state: WalletState) throws -> WalletState {
        guard state.lifecycleState == .active else {
            throw WalletError.walletLocked
        }

        guard transaction.from == state.walletID else {
            throw WalletError.unsupportedSender(expected: state.walletID, received: transaction.from)
        }

        guard transaction.from != transaction.to else {
            throw WalletError.selfTransferAttempt
        }

        guard transaction.amount > 0 else {
            throw WalletError.invalidAmount
        }

        // Duplicate id detection is intentionally treated as explicit replay protection,
        // separate from the strictly sequential nonce check.
        guard !state.containsRecentTransactionID(transaction.id) else {
            throw WalletError.duplicateTransaction(id: transaction.id)
        }

        guard transaction.nonce == state.nextExpectedNonce else {
            throw WalletError.invalidNonce(expected: state.nextExpectedNonce, received: transaction.nonce)
        }

        guard state.balance >= transaction.amount else {
            throw WalletError.insufficientBalance(available: state.balance, requested: transaction.amount)
        }

        let request = SignatureVerificationRequest(
            signer: transaction.from,
            message: canonicalMessage(for: transaction),
            signature: transaction.signature
        )
        guard verifier.verify(request) else {
            throw WalletError.invalidSignature
        }

        return state.recordingAppliedTransaction(id: transaction.id, debitedAmount: transaction.amount)
    }
}
