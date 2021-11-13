//
//  Varnam.swift
//  VarnamIME
//
//  Created by Subin on 13/11/21.
//  Copyright © 2021 VarnamProject. All rights reserved.
//

import Foundation

struct VarnamException: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}

public class Varnam {
    private var varnamHandle: Int32 = 0;
    
    internal init(_ schemeID: String = "ml") throws {
        schemeID.withCString {
            let rc = varnam_init_from_id(UnsafeMutablePointer(mutating: $0), &varnamHandle)
            try! checkError(rc)
        }
    }
    
    public func getLastError() -> String {
        return String(cString: varnam_get_last_error(varnamHandle))
    }
    
    public func checkError(_ rc: Int32) throws {
        if (rc != VARNAM_SUCCESS) {
            throw VarnamException(getLastError())
        }
    }

    public func transliterate(_ input: String) -> [String] {
        var arr: UnsafeMutablePointer<varray>? = varray_init()
        let cInput = (input as NSString).utf8String
        varnam_transliterate(
            varnamHandle,
            1,
            UnsafeMutablePointer(mutating: cInput),
            &arr
        )

        var results = [String]()
        for i in (0..<varray_length(arr)) {
            let sug = varray_get(arr, i).assumingMemoryBound(to: Suggestion.self
            )
            let word = String(cString: sug.pointee.Word)
            results.append(word)
        }
        return results
    }
}
