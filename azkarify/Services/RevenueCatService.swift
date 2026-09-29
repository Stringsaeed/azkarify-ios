import Foundation
import RevenueCat

@MainActor
enum RevenueCatService {
  static let isConfigured: Bool = {
    let key = "appl_dWhAUrUEvPeMSUsNAHUqrtGZDit"
    #if DEBUG
      Purchases.logLevel = .debug
    #endif
    Purchases.configure(withAPIKey: key)
    return true
  }()
}
