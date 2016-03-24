//
//  EurekaSwiftValidatorComponents.swift
//  Examples
//
//  Created by Demetrio Filocamo on 12/03/2016.
//  Copyright © 2016 Novaware Ltd. All rights reserved.
//
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Fixes & Modifications by Keary Griffin, RocketFarmStudios

import Eureka
import SwiftValidator
import ObjectiveC

public class _SVFieldCell<T where T: Equatable, T: InputTypeInitiable>: _FieldCell<T> {

    required public init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    lazy public var validationLabel: UILabel = {
        [unowned self] in
        let validationLabel = UILabel()
        validationLabel.translatesAutoresizingMaskIntoConstraints = false
        validationLabel.font = validationLabel.font.fontWithSize(10.0)
        return validationLabel
        }()

    public override func setup() {
        super.setup()
        textField.autocorrectionType = .Default
        textField.autocapitalizationType = .Sentences
        textField.keyboardType = .Default

        self.height = {
            60
        }
        contentView.addSubview(validationLabel)

        let sameLeading: NSLayoutConstraint = NSLayoutConstraint(item: self.contentView, attribute: .Leading, relatedBy: .Equal, toItem: self.validationLabel, attribute: .Leading, multiplier: 1, constant: -20)
        let sameTrailing: NSLayoutConstraint = NSLayoutConstraint(item: self.textField, attribute: .Trailing, relatedBy: .Equal, toItem: self.validationLabel, attribute: .Trailing, multiplier: 1, constant: 0)
        let sameBottom: NSLayoutConstraint = NSLayoutConstraint(item: self.contentView, attribute: .Bottom, relatedBy: .Equal, toItem: self.validationLabel, attribute: .Bottom, multiplier: 1, constant: 4)
        let all: [NSLayoutConstraint] = [sameLeading, sameTrailing, sameBottom]

        contentView.addConstraints(all)

        validationLabel.textAlignment = NSTextAlignment.Right
        validationLabel.adjustsFontSizeToFitWidth = true
        resetField()
    }

    func setRules(rules: [Rule]?) {
        self.rules = rules
    }

    override public func textFieldDidChange(textField: UITextField) {
        super.textFieldDidChange(textField)

        if autoValidation {
            validate()
        }
    }

    // MARK: - Validation management

    func validate() {
        if let v = self.validator {
            // Registering the rules
            if !rulesRegistered {
                v.unregisterField(textField)  //  in case the method has already been called
                if let r = rules {
                    v.registerField(textField, errorLabel: validationLabel, rules: r)
                }
                self.rulesRegistered = true
            }

            self.valid = true

            v.validate({
                (errors) -> Void in
                self.resetField()
                for (field, error) in errors {
                    self.valid = false
                    self.showError(field, error: error)
                }
            })
        } else {
            self.valid = false
        }
    }

    func resetField() {
        validationLabel.hidden = true
        textField.textColor = UIColor.blackColor()
        //textLabel?.textColor = UIColor.blackColor();
    }

    func showError(field: UITextField, error: ValidationError) {
        // turn the field to red
        field.textColor = errorColor
        /*
        if let ph = field.placeholder {
            let str = NSAttributedString(string: ph, attributes: [NSForegroundColorAttributeName: errorColor])
            field.attributedPlaceholder = str
        }
        */
        //self.textLabel?.textColor = errorColor
        self.validationLabel.textColor = errorColor
        error.errorLabel?.text = error.errorMessage // works if you added labels
        error.errorLabel?.hidden = false
    }

    var validator: Validator? {
        get {
            if let fvc = formViewController() {
                return fvc.form.validator
            }
            return nil;
        }
    }

    var errorColor: UIColor = UIColor.redColor()
    var autoValidation = true
    var rules: [Rule]? = nil

    private var rulesRegistered = false
    var valid = false
}


public protocol SVRow {
    var errorColor: UIColor { get set }

    var rules: [Rule]? { get set }

    var autoValidation: Bool { get set }

    var valid: Bool { get }

    func validate();
}

public class _SVTextRow<Cell: _SVFieldCell<String> where Cell: BaseCell, Cell: CellType, Cell: TextFieldCell, Cell.Value == String>: FieldRow<String, Cell>, SVRow {
    public required init(tag: String?) {
        super.init(tag: tag)
    }

    public var errorColor: UIColor {
        get {
            return self.cell.errorColor
        }
        set {
            self.cell.errorColor = newValue
        }
    }

    public var rules: [Rule]? {
        get {
            return self.cell.rules
        }
        set {
            self.cell.setRules(newValue)
        }
    }

    public var autoValidation: Bool {
        get {
            return self.cell.autoValidation
        }
        set {
            self.cell.autoValidation = newValue
        }
    }

    public var valid: Bool {
        get {
            return self.cell.valid
        }
    }

    public func validate() {
        self.cell.validate()
    }
}

public class SVTextCell: _SVFieldCell<String>, CellType {

    required public init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    public override func setup() {
        super.setup()
        textField.autocorrectionType = .Default
        textField.autocapitalizationType = .Sentences
        textField.keyboardType = .Default
    }
}

public class SVAccountCell: SVTextCell {

    public override func setup() {
        super.setup()
        textField.autocorrectionType = .No
        textField.autocapitalizationType = .None
        textField.keyboardType = .ASCIICapable
    }
}

public class SVPhoneCell: SVTextCell {

    public override func setup() {
        super.setup()
        textField.keyboardType = .PhonePad
    }
}

public class SVSimplePhoneCell: SVTextCell {

    public override func setup() {
        super.setup()
        textField.keyboardType = .NumberPad
    }
}

public class SVNameCell: SVTextCell {

    public override func setup() {
        super.setup()
        textField.autocorrectionType = .No
        textField.autocapitalizationType = .Words
        textField.keyboardType = .ASCIICapable    }
}

public class SVEmailCell: SVTextCell {

    public override func setup() {
        super.setup()
        textField.autocorrectionType = .No
        textField.autocapitalizationType = .None
        textField.keyboardType = .EmailAddress
    }
}

public class SVPasswordCell: SVTextCell {

    public override func setup() {
        super.setup()
        textField.autocorrectionType = .No
        textField.autocapitalizationType = .None
        textField.keyboardType = .ASCIICapable
        textField.secureTextEntry = true
    }
}

public class SVURLCell: SVTextCell {

    public override func setup() {
        super.setup()
        textField.autocorrectionType = .No
        textField.autocapitalizationType = .None
        textField.keyboardType = .URL    }
}

public class SVZipCodeCell: SVTextCell {

    public override func setup() {
        super.setup()
        textField.autocorrectionType = .No
        textField.autocapitalizationType = .AllCharacters
        textField.keyboardType = .NumbersAndPunctuation
    }
}


extension Form {

    private struct AssociatedKey {
        static var validator: UInt8 = 0
        static var dataValid: UInt8 = 0
    }

    var validator: Validator {
        get {
            if let validator = objc_getAssociatedObject(self, &AssociatedKey.validator) {
                return validator as! Validator
            } else {
                let v = Validator()
                self.validator = v
                return v
            }
        }

        set {
            objc_setAssociatedObject(self, &AssociatedKey.validator, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var dataValid: Bool {
        get {
            if let dv = objc_getAssociatedObject(self, &AssociatedKey.dataValid) {
                return dv as! Bool
            } else {
                let dv = false
                self.dataValid = dv
                return dv
            }
        }

        set {
            objc_setAssociatedObject(self, &AssociatedKey.dataValid, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func validateAll() -> Bool {
        dataValid = true

        let rows = allRows
        for row in rows {
            if row is SVRow {
                var svRow = (row as! SVRow)
                svRow.validate()
                let rowValid = svRow.valid
                svRow.autoValidation = true // from now on autovalidation is enabled
                if !rowValid && dataValid {
                    dataValid = false
                }
            }
        }
        return dataValid
    }
}

/// A String valued row where the user can enter arbitrary text.

public final class SVTextRow: _SVTextRow<SVTextCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVAccountRow: _SVTextRow<SVAccountCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVPhoneRow: _SVTextRow<SVPhoneCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVSimplePhoneRow: _SVTextRow<SVSimplePhoneCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVNameRow: _SVTextRow<SVNameCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVEmailRow: _SVTextRow<SVEmailCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVPasswordRow: _SVTextRow<SVPasswordCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVURLRow: _SVTextRow<SVURLCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVZipCodeRow: _SVTextRow<SVZipCodeCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

// TODO add more