//
//  Helper.swift
//  MySwiftHttp
//
//  Created by 叶金永 on 2018/8/24.
//  Copyright © 2018年 Keyon. All rights reserved.
//

import Foundation

extension CharacterSet {
	static var urlQueryParametersAllowed: CharacterSet {
		/// Does not include "?" or "/" due to RFC 3986 - Section 3.4
		let generalDelimitersToEncode = ":#[]@"
		let subDelimitersToEncode = "!$&'()*+,;="
		
		var allowedCharacterSet = CharacterSet.urlQueryAllowed
		allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
		
		return allowedCharacterSet
	}
}

public extension Dictionary where Key: ExpressibleByStringLiteral {
	
	/// Encodes the contents of the dictionary
	///
	/// - Returns: Returns the parameters in using URL-enconding, for example ["username": "Michael", "age": 20] will become "username=Michael&age=20".
	/// - Throws: Returns an error if it wasn't able to encode the dictionary.
	public func urlEncodedString() throws -> String {
		
		let pairs = try reduce([]) { current, keyValuePair -> [String] in
			if let encodedValue = "\(keyValuePair.value)".addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed) {
				debugPrint(current)
				return current + ["\(keyValuePair.key)=\(encodedValue)"]
			} else {
				throw NSError(domain: "com.Keyon.networking", code: 0, userInfo: [NSLocalizedDescriptionKey: "Couldn't encode \(keyValuePair.value)"])
			}
		}
		
		let converted = pairs.joined(separator: "&")
		
		return converted
	}
}

extension String {
	
	func encodeUTF8() -> String? {
		if let _ = URL(string: self) {
			return self
		}
		
		var components = self.components(separatedBy: "/")
		guard let lastComponent = components.popLast(),
			let endcodedLastComponent = lastComponent.addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed) else {
				return nil
		}
		
		return (components + [endcodedLastComponent]).joined(separator: "/")
	}
}
