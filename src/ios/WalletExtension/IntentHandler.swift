import Intents
import UIKit
import Foundation
import PassKit
import LocalAuthentication
import Security
 
struct CardDetailsResponse: Codable {
    let cardId: String
    let cardTitle: String
    let maskedCardNumber: String
    let artUrl: String
    let cardType: String
    let holderName: String
    
    enum CodingKeys: String, CodingKey {
        case cardId = "cardId"
        case cardTitle = "CardTitle"
        case maskedCardNumber = "maskedCardNumber"
        case artUrl = "ArtUrl"
        case cardType = "cardType"
        case holderName = "HolderName"
    }
    
}

struct WalletStatus {
    let sessionToken: String
    let hasEligibleCards: Bool
    let baseURL: String
    let custnin: String
}
 
struct PayloadDetailsResponse: Codable {
    let activationData: String?
    let encryptedData: String?
    let ephermeralPublicKey: String?
 
    enum CodingKeys: String, CodingKey {
        case activationData = "ActivationData"
        case encryptedData = "EncryptedData"
        case ephermeralPublicKey = "EphemeralPublicKey"
    }
}

let appGroupID: String = "group.com.aub.mobilebanking"
let keychainStoreDataKey = "walletStatusToken"
 
class IntentHandler: PKIssuerProvisioningExtensionHandler {
    
    let passLibrary = PKPassLibrary()
    
    // MARK: - Required Methods
    func authorize(completion: @escaping (PKIssuerProvisioningExtensionAuthorizationResult) -> Void) {
        completion(.authorized)
    }
    
    func saveDictionaryToKeychain(
        _ dictionary: [String: Any],
        key: String,
        service: String = appGroupID
    ) throws {

        let data = try dictionaryToData(dictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status))
        }
    }

    func readDictionaryFromKeychain(
        key: String,
        service: String = appGroupID
    ) throws -> [String: Any]? {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
//        guard status == errSecSuccess else { return nil }

        if status != errSecSuccess {
            return nil
        }

        guard let data = result as? Data else {
            return nil
        }

        return try dataToDictionary(data)
    }

    func dictionaryToData(_ dictionary: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: dictionary, options: [])
    }

    func dataToDictionary(_ data: Data) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }

    override func status(completion: @escaping (PKIssuerProvisioningExtensionStatus) -> Void) {

        let status = PKIssuerProvisioningExtensionStatus()
        
//        try? saveDictionaryToKeychain(
//                [
//                    "sessionToken": "eyJhbGciOiJIUzUxMiIsImtpZCI6IjY3NDdkNTdjLWExM2QtNGIyYi04NTg1LThiY2ZlNThjODk5NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJPdGhlcnMiLCJqdGkiOiIzMDIwNjIxMTYwMTY4MSIsIm5iZiI6MTc2NjIyMzY4NiwiZXhwIjoxNzY2MjIzNzQ2LCJpYXQiOjE3NjYyMjM2ODYsImlzcyI6IkVHWVBUX1Rva2VuIiwiYXVkIjoiaHR0cDovL3d3dy5haGxpdW5pdGVkLmNvbSJ9.iqU1JQvyi2zT1o8MfLvtyEisNyJr8oWwRB37R40Qu0az7yKGGJeAVbksv4MF6JXXDE-3aJoLxnrhw3sajVuDdg",//"TEST123",
//                    "hasEligibleCards": "true",
//                    "URL": "https://dev.ahliunited.com",
//                    "custnin": "26201062100188"
//                ],
//                key: keychainStoreDataKey
//            )

        do {
            guard let walletStatus = try getWalletStatus() else {
                completion(status)
                return
            }

            guard !walletStatus.sessionToken.isEmpty, walletStatus.hasEligibleCards else {
                completion(status)
                return
            }

            status.requiresAuthentication = true
            status.passEntriesAvailable = walletStatus.hasEligibleCards
            status.remotePassEntriesAvailable = true

            completion(status)

        } catch {
            completion(status)
        }
    }
    
    override func passEntries(completion: @escaping ([PKIssuerProvisioningExtensionPassEntry]) -> Void) {
        
        do {
            guard let walletStatus = try getWalletStatus() else {
                completion([])
                return
            }
            
            fetchCardDetails(baseURL: walletStatus.baseURL) { result in
                switch result {
                case .success(let cards):
                    Task {
                        var passEntries: [PKIssuerProvisioningExtensionPassEntry] = []
                        for card in cards {
                            if let entry = await self.getPaymentPassEntry(card: card, baseURL: walletStatus.baseURL) {
                                passEntries.append(entry)
                            }
                        }
                        completion(passEntries)
                    }
                case .failure(_):
                    completion([])
                }
            }
        } catch {
            completion([])
        }
    }
    
    override func remotePassEntries(completion: @escaping ([PKIssuerProvisioningExtensionPassEntry]) -> Void) {
        do {
            guard let walletStatus = try getWalletStatus() else {
                completion([])
                return
            }
            
            fetchCardDetails(baseURL: walletStatus.baseURL) { result in
                switch result {
                case .success(let cards):
                    Task {
                        var passEntries: [PKIssuerProvisioningExtensionPassEntry] = []
                        for card in cards {
                            if let entry = await self.getPaymentPassEntry(card: card, baseURL: walletStatus.baseURL) {
                                passEntries.append(entry)
                            }
                        }
                        completion(passEntries)
                    }
                case .failure(_):
                    completion([])
                }
            }
        } catch {
            completion([])
        }
    }
    
    override func generateAddPaymentPassRequestForPassEntryWithIdentifier(
        _ identifier: String,
        configuration: PKAddPaymentPassRequestConfiguration,
        certificateChain certificates: [Data],
        nonce: Data,
        nonceSignature: Data,
        completionHandler completion: @escaping (PKAddPaymentPassRequest?) -> Void
    ) {
        let request = PKAddPaymentPassRequest()
        
        do {
            guard let walletStatus = try getWalletStatus(),
                  certificates.count > 0 else {
                completion(request)
                return
            }
            
            let requestBody: [String: String] = [
                "certificatepem": certificates[0].base64EncodedString(),
                "nonce": nonce.base64EncodedString(),
                "nonceSignature": nonceSignature.base64EncodedString(),
                "Custnin": walletStatus.custnin,
                "CardNo": configuration.primaryAccountSuffix ?? ""
            ]
            
            postPayloadDetails(baseURL: walletStatus.baseURL,  body: requestBody) { result in
                switch result {
                case .success(let data):
                    request.activationData = Data(base64Encoded: data.activationData ?? "")
                    request.encryptedPassData = Data(base64Encoded: data.encryptedData ?? "")
                    request.ephemeralPublicKey = Data(base64Encoded: data.ephermeralPublicKey ?? "")
                    completion(request)
                case .failure(_):
                    completion(request)
                }
            }
        } catch {
            completion(request)
        }
    }
    
    // MARK: - Helper Methods
    private func getPaymentPassEntry(card: CardDetailsResponse, baseURL: String) async -> PKIssuerProvisioningExtensionPaymentPassEntry? {
        guard let requestConfig = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2) else {
            return nil
        }
        
        let url = "\(baseURL)\(card.artUrl)"
        
        requestConfig.primaryAccountIdentifier = card.cardId
        requestConfig.paymentNetwork = .masterCard // Update based on cardType if needed
        requestConfig.cardholderName = card.holderName
        requestConfig.localizedDescription = card.cardTitle
        requestConfig.primaryAccountSuffix = String(card.maskedCardNumber.suffix(4))
        requestConfig.style = .payment
        
        do {
            let cgImage = try await cgImage(from: url)
            return PKIssuerProvisioningExtensionPaymentPassEntry(
                identifier: card.cardId,
                title: card.cardTitle,
                art: cgImage,
                addRequestConfiguration: requestConfig
            )
        } catch {
            return PKIssuerProvisioningExtensionPaymentPassEntry(
                identifier: card.cardId,
                title: card.cardTitle,
                art: defaultCGImage()!,
                addRequestConfiguration: requestConfig
            )
        }
    }
    
    func defaultCGImage(
        width: Int = 100,
        height: Int = 100,
        color: UIColor = .lightGray
    ) -> CGImage? {
 
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
 
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
 
        context?.setFillColor(color.cgColor)
        context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
 
        return context?.makeImage()
    }
    
    private func cgImage(from urlString: String) async throws -> CGImage {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image"])
        }
        
        return cgImage
    }
    
    // MARK: - Missing Helper Methods
    // You need to implement these or ensure they exist elsewhere
    private func getWalletStatus() throws -> WalletStatus? {

        guard let dict = try readDictionaryFromKeychain(key: keychainStoreDataKey) else {
            return nil
        }

        let sessionToken = dict["sessionToken"] as? String ?? ""
        let hasEligibleCardsString = dict["hasEligibleCards"] as? String ?? "false"
        let hasEligibleCards = hasEligibleCardsString.lowercased() == "true"
        let baseURL = dict["URL"] as? String ?? ""
        let custnin = dict["custnin"] as? String ?? ""


        guard !sessionToken.isEmpty, !baseURL.isEmpty, !custnin.isEmpty else {
            return nil
        }

        return WalletStatus(
            sessionToken: sessionToken,
            hasEligibleCards: hasEligibleCards,
            baseURL: baseURL,
            custnin: custnin
        )
    }

    
    private func fetchCardDetails(
        baseURL: String,
        completion: @escaping (Result<[CardDetailsResponse], Error>) -> Void
    ) {

        guard let walletStatus = try? getWalletStatus() else {
            completion(.failure(NSError(domain: "WalletStatusMissing", code: -1)))
            return
        }

        let urlString =
            "\(baseURL)/EG_OSL_Card_Services_IS/rest/ExtentionCardDetails/CardDetails"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(walletStatus.sessionToken, forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "Custnin": walletStatus.custnin
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }

            do {
                let cards = try JSONDecoder().decode([CardDetailsResponse].self, from: data)
                completion(.success(cards))
            } catch {
                completion(.failure(error))
            }

        }.resume()
    }

    
    private func postPayloadDetails(baseURL: String, body: [String: String], completion: @escaping (Result<PayloadDetailsResponse, Error>) -> Void) {
        // Implement network call to post payload
        
        guard let walletStatus = try? getWalletStatus() else {
            completion(.failure(NSError(domain: "WalletStatusMissing", code: -1)))
            return
        }
        
        let urlString = "\(baseURL)/EG_OSL_Card_Services_IS/rest/ExtentionCardDetails/ExtensionFinalOutput"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
 
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(walletStatus.sessionToken, forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [body])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
 
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(PayloadDetailsResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
