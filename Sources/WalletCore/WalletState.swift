import Foundation

public enum WalletLifecycleState: Sendable, Equatable {
    case active
    case locked
}

public struct WalletState: Sendable, Equatable {
    public let walletID: WalletIdentifier
    public let balance: Amount
    public let nextExpectedNonce: UInt64
    public let lifecycleState: WalletLifecycleState
    public let appliedTransactionIDs: Set<TransactionIdentifier>

    public init(
        walletID: WalletIdentifier,
        balance: Amount,
        nextExpectedNonce: UInt64 = 0,
        lifecycleState: WalletLifecycleState = .active,
        appliedTransactionIDs: Set<TransactionIdentifier> = []
    ) {
        self.walletID = walletID
        self.balance = balance
        self.nextExpectedNonce = nextExpectedNonce
        self.lifecycleState = lifecycleState
        self.appliedTransactionIDs = appliedTransactionIDs
    }

    func withLifecycleState(_ lifecycleState: WalletLifecycleState) -> WalletState {
        WalletState(
            walletID: walletID,
            balance: balance,
            nextExpectedNonce: nextExpectedNonce,
            lifecycleState: lifecycleState,
            appliedTransactionIDs: appliedTransactionIDs
        )
    }
}

public enum WalletEvent: Sendable, Equatable {
    case applyTransaction(TransactionProposal)
    case lock
    case unlock
}

public struct WalletTransition: Sendable, Equatable {
    public let event: WalletEvent
    public let previousState: WalletState
    public let nextState: WalletState

    public init(event: WalletEvent, previousState: WalletState, nextState: WalletState) {
        self.event = event
        self.previousState = previousState
        self.nextState = nextState
    }
}
