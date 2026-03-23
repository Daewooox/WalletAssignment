import Foundation

public enum WalletError: Error, Sendable, Equatable {
    case insufficientBalance(available: Amount, requested: Amount)
    case invalidNonce(expected: UInt64, received: UInt64)
    case duplicateTransaction(id: TransactionIdentifier)
    case invalidSignature
    case walletLocked
    case selfTransferAttempt
    case invalidAmount
    case unsupportedSender(expected: WalletIdentifier, received: WalletIdentifier)
}

extension WalletError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .insufficientBalance(available, requested):
            "Insufficient balance. Available: \(available), requested: \(requested)."
        case let .invalidNonce(expected, received):
            "Invalid nonce. Expected: \(expected), received: \(received)."
        case let .duplicateTransaction(id):
            "Duplicate transaction detected for id '\(id)'."
        case .invalidSignature:
            "Signature verification failed."
        case .walletLocked:
            "Wallet is locked."
        case .selfTransferAttempt:
            "Self-transfer attempt is not allowed."
        case .invalidAmount:
            "Transaction amount must be greater than zero."
        case let .unsupportedSender(expected, received):
            "Unexpected sender. Expected '\(expected)', received '\(received)'."
        }
    }
}
