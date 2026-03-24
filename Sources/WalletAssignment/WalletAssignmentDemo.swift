import Foundation
import WalletCore

@main
struct WalletAssignmentDemo {
    static func main() async {
        let verifier = DeterministicSignatureVerifier()
        let initialState = WalletState(walletID: "AlexWallet", balance: 150, nextExpectedNonce: 7)
        let wallet = WalletActor(initialState: initialState, verifier: verifier)
        let stateMachine = WalletStateMachine(verifier: verifier)

        let transactions = [
            makeTransaction(
                id: "trscn-001",
                from: "AlexWallet",
                to: "MerchantWallet",
                amount: 40,
                nonce: 7,
                stateMachine: stateMachine
            ),
            makeTransaction(
                id: "trscn-002",
                from: "AlexWallet",
                to: "SavingsVault",
                amount: 25,
                nonce: 8,
                stateMachine: stateMachine
            ),
            makeTransaction(
                id: "trscn-invalid-signature",
                from: "AlexWallet",
                to: "UnknownRecipient",
                amount: 10,
                nonce: 9,
                stateMachine: stateMachine,
                tamperSignature: true
            )
        ]

        print("Wallet demo started")
        print("Initial state: \(await wallet.snapshot())")

        for transaction in transactions {
            do {
                let transition = try await wallet.apply(transaction)
                print("Applied transaction \(transaction.id)")
                print("Transitioned to: \(transition.nextState)")
            } catch {
                print("Rejected transaction \(transaction.id): \(error.localizedDescription)")
            }
        }

        do {
            _ = try await wallet.lock()
            let lockedAttempt = makeTransaction(
                id: "trscn-locked",
                from: "AlexWallet",
                to: "FriendWallet",
                amount: 5,
                nonce: 9,
                stateMachine: stateMachine
            )
            _ = try await wallet.apply(lockedAttempt)
        } catch {
            print("Locked wallet behavior: \(error.localizedDescription)")
        }

        print("Final state: \(await wallet.snapshot())")
    }

    private static func makeTransaction(
        id: String,
        from: String,
        to: String,
        amount: Amount,
        nonce: UInt64,
        stateMachine: WalletStateMachine,
        tamperSignature: Bool = false
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
        let signature = tamperSignature
            ? "tampered:\(id)"
            : DeterministicSignatureVerifier.sign(signer: from, message: message)

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
