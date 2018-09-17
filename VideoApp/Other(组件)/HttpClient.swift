//
//  HttpClient.swift
//  iRich
//
//  Created by apple on 2017/2/2.
//  Copyright © 2017年 叶金永. All rights reserved.
//

import UIKit

enum RequestType {
    case GET
    case POST
}

enum ParamType {
	case JSON
	case FORM
}

var timeoutInterval:Double = 30

class HttpClient: NSObject,URLSessionDelegate {
	
	
	fileprivate var contentTypeKey: String {
		return "Content-Type"
	}
	
    deinit {
        session.invalidateAndCancel()
        print("HttpClient deinit")
    }
    
    fileprivate var session: URLSession!

    open static let shareClient:HttpClient = {
       let data = HttpClient()
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        data.session = URLSession(configuration: configuration, delegate: data, delegateQueue: nil)
        return data
    }()
	
	public func composedURL(with path: String) throws -> URL {
		let encodedPath = path.encodeUTF8() ?? path
		guard let url = URL(string: encodedPath) else {
			throw NSError(domain: "com.Keyon.networking", code: 0, userInfo: [NSLocalizedDescriptionKey: "Couldn't create a url encodedPath: \(encodedPath)"])
		}
		return url
	}
	
	func httpRequest(with path:String,requestType type:RequestType,_ paramType:ParamType,parameter param:Any?,completion:@escaping (Data?,Error?) -> Void) -> URLSessionDataTask {
		var request = URLRequest(url: URL(string: path)!)
		request.timeoutInterval = timeoutInterval
		request.cachePolicy = .reloadIgnoringLocalCacheData
		if paramType == .JSON {
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			if let param = param {
				do {
					let data = try JSONSerialization.data(withJSONObject: param, options: .prettyPrinted)
					request.httpBody = data
				} catch {
					print(error)
				}
			}
		} else {
			request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
			guard let parametersDictionary = param as? [String: Any] else { fatalError("Couldn't convert parameters to a dictionary: \(String(describing: param))") }
			do {
				let formattedParameters = try parametersDictionary.urlEncodedString()
				switch type {
				case .GET:
					let urlEncodedPath: String
					if path.contains("?") {
						if let lastCharacter = path.last, lastCharacter == "?" {
							urlEncodedPath = path + formattedParameters
						} else {
							urlEncodedPath = path + "&" + formattedParameters
						}
					} else {
						urlEncodedPath = path + "?" + formattedParameters
					}
					request.url = try! composedURL(with: urlEncodedPath)
				case .POST:
					request.httpBody = formattedParameters.data(using: .utf8)
				}
			} catch let error as NSError {
				print(error)
			}
		}
        switch type {
        case .GET:
            request.httpMethod = "GET"
			if let param = param {
				do {
					let data = try JSONSerialization.data(withJSONObject: param, options: .prettyPrinted)
					request.httpBody = data
				} catch {
					print(error)
				}
			}
        case .POST:
            request.httpMethod = "POST"
			
		}
		let task = session.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
			guard let _ = self else { return } //弱引用
			if let data = data {
				if error == nil {
					completion(data,nil)
				}else {
					completion(nil,error)
				}
			}else {
				completion(nil,error)
			}
		})
		task.resume()
		return task
    }
	
	//handle authenication
	func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		//认证服务器证书
		if challenge.protectionSpace.authenticationMethod
			== NSURLAuthenticationMethodServerTrust {
			debugPrint("服务端证书认证！")
			
			let serverTrust:SecTrust = challenge.protectionSpace.serverTrust!
			let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0)!
			let remoteCertificateData
				= CFBridgingRetain(SecCertificateCopyData(certificate))!
			guard let cerPath = Bundle.main.path(forResource: "release_api", ofType: "cer") else {
				debugPrint("证书路径错误")
				return
			}
			let cerUrl = URL(fileURLWithPath:cerPath)
			let localCertificateData = try! Data(contentsOf: cerUrl)
			
			if (remoteCertificateData.isEqual(localCertificateData) == true) {
				let credential = URLCredential(trust: serverTrust)
				challenge.sender?.use(credential, for: challenge)
				debugPrint("认证通过")
				return completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
			} else {
				debugPrint("认证失败的容错处理")
				return completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
			}
		}
			//认证客户端证书
		else if challenge.protectionSpace.authenticationMethod
			== NSURLAuthenticationMethodClientCertificate
		{
			debugPrint("客户端证书认证！")
			//获取客户端证书相关信息
			guard let identityAndTrust = self.extractIdentity() else {
				return
			}
			
			let urlCredential:URLCredential = URLCredential(
				identity: identityAndTrust.identityRef,
				certificates: identityAndTrust.certArray as? [AnyObject],
				persistence: URLCredential.Persistence.forSession)
			
			return completionHandler(.useCredential, urlCredential)
		}
			// 其它情况（不接受认证）
		else {
			debugPrint("其它情况（不接受认证）")
			return
		}
	}
	
	func extractIdentity() -> IdentityAndTrust? {
		var identityAndTrust:IdentityAndTrust!
		var securityError:OSStatus = errSecSuccess
		
		guard let path: String = Bundle.main.path(forResource: "mykey", ofType: "p12"),let PKCS12Data = NSData(contentsOfFile:path) else {
			debugPrint("证书路径错误")
			return nil
		}
		let key : NSString = kSecImportExportPassphrase as NSString
		let options : NSDictionary = [key : "123456"] //客户端证书密码
		//create variable for holding security information
		//var privateKeyRef: SecKeyRef? = nil
		
		var items : CFArray?
		
		securityError = SecPKCS12Import(PKCS12Data, options, &items)
		
		if securityError == errSecSuccess {
			let certItems:CFArray = items!;
			let certItemsArray:Array = certItems as Array
			let dict:AnyObject? = certItemsArray.first;
			if let certEntry:Dictionary = dict as? Dictionary<String, AnyObject> {
				// grab the identity
				let identityPointer:AnyObject? = certEntry["identity"]
				let secIdentityRef:SecIdentity = identityPointer as! SecIdentity
				// grab the trust
				let trustPointer:AnyObject? = certEntry["trust"]
				let trustRef:SecTrust = trustPointer as! SecTrust
				// grab the cert
				let chainPointer:AnyObject? = certEntry["chain"]
				identityAndTrust = IdentityAndTrust(identityRef: secIdentityRef,
													trust: trustRef, certArray:  chainPointer!)
			}
		}
		return identityAndTrust;
	}
}

//定义一个结构体，存储认证相关信息
struct IdentityAndTrust {
	var identityRef:SecIdentity
	var trust:SecTrust
	var certArray:AnyObject
}
