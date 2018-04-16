//
//  M4AFileSheet.swift
//  Musicler
//
//  Created by Andrew Hyatt on 3/8/18.
//  Copyright © 2018 Andrew Hyatt. All rights reserved.
//

import Cocoa
import M4ATools

class M4AFileSheet: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {

    class EditorState {
        
        var path: String
        var file: M4AFile
        var searchResults = [iTunesResult]()
        var searchText: String? = nil
        var selectedResult: iTunesResult? = nil
        var selectedRow: Int?
        
        init(path: String, file: M4AFile) {
            self.path = path
            self.file = file
        }
        
    }
    
    var files: [String]!
    var fileIndex = 0
    
    var state: EditorState!
    var states = [String : EditorState]()
    
    @IBOutlet weak var searchField: NSTextField!
    @IBOutlet weak var searchTableView: NSTableView!
    @IBOutlet weak var songTableView: NSTableView!
    
    var itunesSearcher = iTunesSearcher()
    
    @IBOutlet weak var trackTableView: NSTableView!
    @IBOutlet weak var resultsTableView: NSTableView!
    
    @IBOutlet weak var okButton: NSButton!
    
    @IBOutlet weak var leftButton: NSButton!
    @IBOutlet weak var rightButton: NSButton!
    
    @IBOutlet weak var navLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        loadFile()
        
        if let fileName = state?.file.fileName {
            searchField.stringValue = fileName.replacingOccurrences(of:
                ".m4a", with: "")
        }
        
        reloadButtons()
        
        navLabel.stringValue = "File \(fileIndex + 1) of \(files.count) (\(state.file.fileName!))"
    }
    
    @IBAction func searchPressed(_ sender: NSButton) {
        itunesSearcher.trackName = searchField.stringValue
        state.searchResults = itunesSearcher.search()
        resultsTableView.reloadData()
    }
    
    @IBAction func okPressed(_ sender: NSButton) {
        for (_, state) in states {
            let result = state.selectedResult!
            result.writeMetadata(m4aFile: state.file)
        }
        dismissViewController(self)
    }
    
    @IBAction func previousFile(_ sender: NSButton) {
        guard canShowPrevious() else {
            print("\(#function) called at an incorrect time")
            return
        }
        fileIndex -= 1
        loadFile()
        reset()
    }
    
    @IBAction func nextFile(_ sender: NSButton) {
        guard canShowNext() else {
            print("\(#function) called at an incorrect time")
            return
        }
        fileIndex += 1
        loadFile()
        reset()
    }
    
    func reset() {
        resultsTableView.reloadData()
        songTableView.reloadData()
        
        if let row = state?.selectedRow {
            resultsTableView.selectRowIndexes([row], byExtendingSelection: false)
        }
        
        if state != nil {
            if state.searchText == nil {
                if let fileName = state?.file.fileName {
                    searchField.stringValue = fileName.replacingOccurrences(of:
                        ".m4a", with: "")
                    state.searchText = searchField.stringValue
                }
                
            } else {
                searchField.stringValue = state.searchText!
            }
        }
        reloadButtons()
        
        navLabel.stringValue = "File \(fileIndex + 1) of \(files.count) (\(state.file.fileName!))"
    }
    
    func loadFile() {
        let filePath = files[fileIndex]
        if let state = states[filePath] {
            self.state = state
        } else {
            let url = URL(fileURLWithPath: filePath)
            do {
                let m4aFile = try M4AFile(url: url)
                
                let state = EditorState(path: filePath, file: m4aFile)
                states[filePath] = state
                self.state = state
            } catch {
                presentError(error)
            }
        }
    }
    
    func canShowPrevious() -> Bool {
        return fileIndex > 0
    }
    
    func canShowNext() -> Bool {
        return fileIndex < files.count - 1 && state.selectedResult != nil
    }
    
    func canShowOK() -> Bool {
        // Check that every state has a selected result
        for (_, state) in states {
            if state.selectedResult == nil || state.selectedRow == nil {
                return false
            }
        }
        return true
    }
    
    func reloadButtons() {
        leftButton.isEnabled = canShowPrevious()
        rightButton.isEnabled = canShowNext()
        okButton.isEnabled = canShowOK()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == resultsTableView {
            return state.searchResults.count
        } else {
            return -1
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableView == resultsTableView {
            let result = state.searchResults[row]
            switch tableColumn!.title {
            case "Track":
                var name = result.track.trackName
                if result.track.trackExplicitness == "explicit" {
                    name += " (E)"
                }
                return name
            case "Artist":
                return result.track.artistName
            case "Collection":
                return result.track.collectionName
            default:
                return "Unknown"
            }
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView == resultsTableView {
            state.searchResults[row] = itunesSearcher.loadMoreMetadata(result: state.searchResults[row])
            state.selectedResult = state.searchResults[row]
            state.selectedRow = row
            reloadButtons()
            return true
        } else {
            return true
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        return false
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let table = notification.object as? NSTableView, table == resultsTableView {
            if resultsTableView.selectedRow >= 0 {
                state.selectedRow = resultsTableView.selectedRow
                let result = state.searchResults[resultsTableView.selectedRow]
                state.searchResults[resultsTableView.selectedRow] = itunesSearcher.loadMoreMetadata(result: result)
                state.selectedResult = result
                reloadButtons()
            } else {
                state.selectedRow = nil
                state.selectedResult = nil
                reloadButtons()
            }
        }
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else {
            return
        }
        
        if field == searchField {
            state.searchText = field.stringValue
        }
    }
    
}
