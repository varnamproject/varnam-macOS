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

func strToCStr(_ str: String) -> UnsafeMutablePointer<CChar>? {
    return UnsafeMutablePointer(mutating: (str as NSString).utf8String)
}

public class Varnam {
    private var varnamHandle: Int32 = 0;
    
    // This will only run once
    struct Once {
        static let once = Once()
        init() {
            let assetsFolderPath = Bundle.main.resourceURL!.appendingPathComponent("assets").path
            print(assetsFolderPath)
            varnam_set_vst_lookup_dir(strToCStr(assetsFolderPath))
        }
    }
    
    internal init(_ schemeID: String = "ml") throws {
        _ = Once.once

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
    
    public func close() {
        varnam_close(varnamHandle)
    }

    public func transliterate(_ input: String) -> [String] {
        var arr: UnsafeMutablePointer<varray>? = varray_init()
        varnam_transliterate(
            varnamHandle,
            1,
            strToCStr(input),
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
