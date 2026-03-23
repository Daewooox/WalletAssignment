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
        let transition = try stateMachine.transition(from: state, event: .applyTransaction(transaction))
        state = transition.nextState
        return transition
    }

    @discardableResult
    public func lock() -> WalletTransition {
        let nextState = state.withLifecycleState(.locked)
        let transition = WalletTransition(event: .lock, previousState: state, nextState: nextState)
        state = transition.nextState
        return transition
    }

    @discardableResult
    public func unlock() -> WalletTransition {
        let nextState = state.withLifecycleState(.active)
        let transition = WalletTransition(event: .unlock, previousState: state, nextState: nextState)
        state = transition.nextState
        return transition
    }
}
