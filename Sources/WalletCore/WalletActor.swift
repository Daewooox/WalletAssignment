import Foundation

public actor WalletActor {
    private let stateMachine: WalletStateMachine
    private var state: WalletState

    public init(initialState: WalletState, verifier: any SignatureVerifying) {
        self.state = initialState
        self.stateMachine = WalletStateMachine(verifier: verifier)
    }

    public func snapshot() -> WalletState {
        state
    }

    @discardableResult
    public func apply(_ transaction: TransactionProposal) throws -> WalletTransition {
        try perform(.applyTransaction(transaction))
    }

    @discardableResult
    public func lock() throws -> WalletTransition {
        try perform(.lock)
    }

    @discardableResult
    public func unlock() throws -> WalletTransition {
        try perform(.unlock)
    }

    private func perform(_ event: WalletEvent) throws -> WalletTransition {
        let transition = try stateMachine.transition(from: state, event: event)
        state = transition.nextState
        return transition
    }
}
