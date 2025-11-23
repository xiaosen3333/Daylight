import Foundation

enum DomainError: Error, LocalizedError {
    case invalidInput(String)
    case storageFailure(String)
    case syncFailure(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .storageFailure(let message):
            return message
        case .syncFailure(let message):
            return message
        case .notFound:
            return "未找到对应记录"
        }
    }
}
