import Foundation

public typealias WalletIdentifier = String
public typealias TransactionIdentifier = String
public typealias Signature = String
public typealias Amount = UInt64

public struct TransactionProposal: Sendable, Equatable {
    public let id: TransactionIdentifier
    public let from: WalletIdentifier
    public let to: WalletIdentifier
    public let amount: Amount
    public let nonce: UInt64
    public let signature: Signature

    public init(
        id: TransactionIdentifier,
        from: WalletIdentifier,
        to: WalletIdentifier,
        amount: Amount,
        nonce: UInt64,
        signature: Signature
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.amount = amount
        self.nonce = nonce
        self.signature = signature
    }
}

public struct SignatureVerificationRequest: Sendable, Equatable {
    public let signer: WalletIdentifier
    public let message: String
    public let signature: Signature

    public init(signer: WalletIdentifier, message: String, signature: Signature) {
        self.signer = signer
        self.message = message
        self.signature = signature
    }
}

public protocol SignatureVerifying: Sendable {
    func verify(_ request: SignatureVerificationRequest) -> Bool
}

public struct DeterministicSignatureVerifier: SignatureVerifying {
    public init() {}

    public func verify(_ request: SignatureVerificationRequest) -> Bool {
        request.signature == Self.sign(signer: request.signer, message: request.message)
    }

    public static func sign(signer: WalletIdentifier, message: String) -> Signature {
        "signed:\(signer):\(message)"
    }
}
