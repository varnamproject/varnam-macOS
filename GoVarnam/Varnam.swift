//
//  Varnam.swift
//  VarnamIME
//
//  Created by Subin on 13/11/21.
//  Copyright © 2021 VarnamProject. All rights reserved.
//

import Foundation

public struct VarnamException: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}

public struct SchemeDetails {
    var Identifier: String
    var LangCode: String
    var DisplayName: String
    var Author: String
    var CompiledDate: String
    var IsStable: Bool
}

extension String {
    func toCStr() -> UnsafeMutablePointer<CChar>? {
        return UnsafeMutablePointer(mutating: (self as NSString).utf8String)
    }
}

public class Varnam {
    private var varnamHandle: Int32 = 0;
    
    static let assetsFolderPath = Bundle.main.resourceURL!.appendingPathComponent("assets").path
    static func importAllVLFInAssets() {
        // TODO import only necessary ones
        let fm = FileManager.default
        for scheme in getAllSchemeDetails() {
            do {
                let varnam = try! Varnam(scheme.Identifier)
                let items = try fm.contentsOfDirectory(atPath: assetsFolderPath)

                for item in items {
                    if item.hasSuffix(".vlf") && item.hasPrefix(scheme.Identifier) {
                        let path = assetsFolderPath + "/" + item
                        varnam.importFromFile(path)
                    }
                }
            } catch {
                Logger.log.error("Couldn't import")
            }
        }
    }
    
    static func setVSTLookupDir(_ path: String) {
        varnam_set_vst_lookup_dir(assetsFolderPath.toCStr())
    }
    
    // This will only run once
    struct VarnamInit {
        static let once = VarnamInit()
        init() {
            print(assetsFolderPath)
            Varnam.setVSTLookupDir(assetsFolderPath)
        }
    }
    
    internal init(_ schemeID: String = "ml") throws {
        _ = VarnamInit.once

        try checkError(varnam_init_from_id(schemeID.toCStr(), &varnamHandle))
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
            input.toCStr(),
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
    
    public func learn(_ input: String) throws {
        try checkError(varnam_learn(varnamHandle, input.toCStr(), 0))
    }
    
    public func importFromFile(_ path: String) {
        varnam_import(varnamHandle, path.toCStr())
    }
    
    public static func getAllSchemeDetails() -> [SchemeDetails] {
        _ = VarnamInit.once
        
        var schemes = [SchemeDetails]()

        let arr = varnam_get_all_scheme_details()
        for i in (0..<varray_length(arr)) {
            let sdPointer = varray_get(arr, i).assumingMemoryBound(to: SchemeDetails_t.self
            )
            let sd = sdPointer.pointee
            schemes.append(SchemeDetails(
                Identifier: String(cString: sd.Identifier),
                LangCode: String(cString: sd.LangCode),
                DisplayName: String(cString: sd.DisplayName),
                Author: String(cString: sd.Author),
                CompiledDate: String(cString: sd.CompiledDate),
                IsStable: (sd.IsStable != 0)
            ))
        }
        return schemes
    }
}
