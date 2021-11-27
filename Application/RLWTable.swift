//
//  RLWTable.swift
//  VarnamApp
//
//  Copyright © 2021 Subin Siby
//

import Foundation

import SwiftUI

extension Double {
    func getDateTimeStringFromUTC() -> String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = DateFormatter.Style.medium //Set time style
        dateFormatter.dateStyle = DateFormatter.Style.medium //Set date style
        dateFormatter.timeZone = .current
        return dateFormatter.string(from: date)
    }
}

struct RLWTable: NSViewControllerRepresentable {
    var words: [Suggestion]
    var unlearn: (String)->()
    typealias NSViewControllerType = RLWTableController

    func makeNSViewController(context: Context) -> RLWTableController {
        return RLWTableController(self)
    }
    
    func updateNSViewController(_ nsViewController: RLWTableController, context: Context) {
        nsViewController.words = words
        nsViewController.table.reloadData()
    }
}

class RLWTableController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    private var wrapper: RLWTable
    
    var table = NSTableView()
    var words: [Suggestion];
    
    init(_ wrapper: RLWTable) {
        self.wrapper = wrapper
        self.words = wrapper.words
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView()
        view.autoresizesSubviews = true
        
        let columns = [
            (title: "Learned On", width: 200.0, tooltip: "Factory name for language"),
            (title: "Word", width: 250.0, tooltip: "Custom name for language"),
            (title: "", width: 10.0, tooltip: "Shortcut to select language"),
        ]
        for column in columns {
            let tableColumn = NSTableColumn()
            tableColumn.headerCell.title = column.title
            tableColumn.headerCell.alignment = .center
            tableColumn.identifier = NSUserInterfaceItemIdentifier(rawValue: column.title)
            tableColumn.width = CGFloat(column.width)
            tableColumn.headerToolTip = column.tooltip
            table.addTableColumn(tableColumn)
        }
        table.allowsColumnResizing = true
        table.allowsColumnSelection = false
        table.allowsMultipleSelection = false
        table.allowsColumnReordering = false
        table.allowsEmptySelection = true
        table.allowsTypeSelect = false
        table.usesAlternatingRowBackgroundColors = true
        table.intercellSpacing = NSSize(width: 15, height: 7)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autoresizingMask = [.height, .width]
        scroll.borderType = .bezelBorder
        view.addSubview(scroll)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        table.delegate = self
        table.dataSource = self
    }
    
    // NSTableViewDataSource
    func numberOfRows(in table: NSTableView) -> Int {
        return words.count
    }
    
    // NSTableViewDelegate
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch tableColumn!.title {
        case "Learned On":
            return NSTextField(string: Double(words[row].LearnedOn).getDateTimeStringFromUTC())
        case "Word":
            return NSTextField(string: words[row].Word)
        case "":
            let btn = NSButton(title: "Unlearn", target: self, action: #selector(self.onChange(receiver:)))
            btn.identifier = tableColumn!.identifier
            return btn
        default:
            Logger.log.fatal("Unknown column title \(tableColumn!.title)")
            fatalError()
        }
    }
    
    @objc func onChange(receiver: Any) {
        let row = table.row(for: receiver as! NSView)
        if row == -1 {
            // The view has changed under us
            return
        }
        wrapper.unlearn(words[row].Word)
    }
}
