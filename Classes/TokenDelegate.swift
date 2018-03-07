//
//  TokenDelegate.swift
//  Subler
//
//  Created by Damiano Galassi on 07/03/2018.
//

import Cocoa

class TokenDelegate: NSObject, NSTokenFieldDelegate {

    let displayMenu: Bool
    let displayString: (Token) -> String

    init(displayMenu: Bool, displayString: @escaping (Token) -> String) {
        self.displayMenu = displayMenu
        self.displayString = displayString
    }

    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
        if let token = representedObject as? Token {
            if token.isPlaceholder {
                return displayString(token)
            } else {
                return token.text
            }
        }
        return representedObject as? String
    }

    func tokenField(_ tokenField: NSTokenField, styleForRepresentedObject representedObject: Any) -> NSTokenField.TokenStyle {
        if let token = representedObject as? Token {
            return token.isPlaceholder ? .rounded : .none
        } else {
            return .none
        }
    }

    func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
        let control = editingString.hasPrefix("{") && editingString.hasSuffix("}")
        return Token(text: editingString, isPlaceholder: control)
    }

//    func tokenField(_ tokenField: NSTokenField, completionsForSubstring substring: String, indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [Any]? {
//        matches = currentTokens.filter { $0.hasPrefix(substring) }
//        return matches
//    }

    func tokenField(_ tokenField: NSTokenField, editingStringForRepresentedObject representedObject: Any) -> String? {
        if let token =  representedObject as? Token {
            return token.isPlaceholder ? "/\(token.text)/" : token.text
        }
        return representedObject as? String
    }

    func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
        return tokens
    }

    private let pasteboardType = NSPasteboard.PasteboardType(rawValue: "SublerTokenDataType")

    func tokenField(_ tokenField: NSTokenField, writeRepresentedObjects objects: [Any], to pboard: NSPasteboard) -> Bool {
        if let tokens = objects as? [Token] {
            if let data = try? JSONEncoder().encode(tokens) {
                pboard.setData(data, forType: pasteboardType)
            }
            let string = tokens.reduce("", { "\($0)/\($1.text)" })
            pboard.setString(string, forType: NSPasteboard.PasteboardType.string)
            return true
        } else {
            return false
        }
    }

    func tokenField(_ tokenField: NSTokenField, readFrom pboard: NSPasteboard) -> [Any]? {
        if let data = pboard.data(forType: pasteboardType),
            let tokens = try? JSONDecoder().decode([Token].self, from: data) {
            return tokens
        } else if let string = pboard.string(forType: .string) {
            return [string]
        } else {
            return nil
        }
    }

    // MARK: Format Token Field Delegate Menu

    func tokenField(_ tokenField: NSTokenField, hasMenuForRepresentedObject representedObject: Any) -> Bool {
        if displayMenu, let token =  representedObject as? Token, token.isPlaceholder {
            return true
        } else {
            return false
        }
    }

    func tokenField(_ tokenField: NSTokenField, menuForRepresentedObject representedObject: Any) -> NSMenu? {
        if let token =  representedObject as? Token, token.isPlaceholder {
            return menu(for: token)
        } else {
            return nil
        }
    }

    @IBAction func setTokenCase(_ sender: NSMenuItem) {}
    @IBAction func setTokenPadding(_ sender: NSMenuItem) {}

    private func menu(for token: Token) -> NSMenu {
        let menu = NSMenu(title: "Item Menu")
        menu.autoenablesItems = false

        menu.addItem(caseMenuItem(title: NSLocalizedString("Capitalize", comment: ""), tag: Token.Case.capitalize.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("lowercase", comment: ""), tag: Token.Case.lower.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("UPPERCASE", comment: ""), tag: Token.Case.upper.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("CamelCase", comment: ""), tag: Token.Case.camel.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("snake_case", comment: ""), tag: Token.Case.snake.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("train-case", comment: ""), tag: Token.Case.train.rawValue, token: token))
        menu.addItem(caseMenuItem(title: NSLocalizedString("dot.case", comment: ""), tag: Token.Case.dot.rawValue, token: token))

        menu.addItem(paddingMenuItem(title: NSLocalizedString("Leading zero", comment: ""), tag: Token.Padding.leadingzero.rawValue, token: token))

        return menu
    }

    private func caseMenuItem(title: String, tag: Int, token: Token) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(setTokenCase(_:)), keyEquivalent: "")
        item.isEnabled = true
        item.representedObject = token
        item.tag = tag
        if tag == token.textCase.rawValue {
            item.state = .on
        }
        return item
    }

    private func paddingMenuItem(title: String, tag: Int, token: Token) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(setTokenPadding(_:)), keyEquivalent: "")
        item.isEnabled = true
        item.representedObject = token
        item.tag = tag
        if tag == token.textPadding.rawValue {
            item.state = .on
        }
        return item
    }

}
