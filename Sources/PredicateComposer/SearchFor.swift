//
//  File.swift
//  
//
//  Created by Simon Fairbairn on 18/02/2022.
//

import CoreData

public enum PredicateType {
	case contains(String?)
	case containsCaseInsensitive(String?)
	case beginsWithCaseInsensitive(String?)
	case isGreaterThan(Int)
	case isLessThan(Int)
	case equals(Any?)
	case isInArray([Any])
	case haveAtLeastOneOf( Any)
	case haveAllOf( Any )
	case isTrue
	case isFalse
}

public enum Match {
	case entity
	case attribute(String)
	case relationshipWithEntityNamed(String)
	case entityRelationshipWithAttribute(String, String)
}

public struct SearchFor {

	let attribute: String
	let predicateType: PredicateType
	let arguments: Any?
	let isToMany: Bool

	public init( _ attribute: Match, that predicateType: PredicateType, arguments: Any? = nil) {
		switch attribute {
		case .entity:
			self.attribute = "self"
			self.isToMany = false
		case .attribute(let attribute):
			self.attribute = attribute
			self.isToMany = false
		case .relationshipWithEntityNamed(let entity):
			self.attribute = entity
			self.isToMany = false
		case .entityRelationshipWithAttribute(let obj, let attribute):
			self.attribute = "\(obj).\(attribute)"
			self.isToMany = true
		}
		self.predicateType = predicateType
		self.arguments = arguments

	}

	// Swift Lint is disabled because I think that this switch is easier to read than
	// breaking it up into multiple functions.
	// swiftlint:disable cyclomatic_complexity
	internal func constructQuery() -> [(String, Any?)]? {
		switch self.predicateType {
		case .isTrue:
			return [("\(isToMany ? "ANY " : "")\(attribute) == true", nil)]
		case .isFalse:
			return [("\(isToMany ? "ANY " : "")\(attribute) == false", nil)]
		case .contains(let argument):
			return (argument == nil) ? nil : [("\(isToMany ? "ANY " : "")\(attribute) CONTAINS %@", argument)]
		case .containsCaseInsensitive(let argument):
			return (argument == nil) ? nil : [("\(isToMany ? "ANY " : "")\(attribute) CONTAINS[c] %@", argument)]
		case .beginsWithCaseInsensitive(let argument):
			return (argument == nil) ? nil : [("\(isToMany ? "ANY " : "")\(attribute) BEGINSWITH[c] %@", argument)]
		case .isLessThan(let argument):
			return [("\(attribute) < %@", argument)]
		case .isGreaterThan(let argument):
			return [("\(attribute) > %@", argument)]
		case .equals(let argument):
			return [("\(attribute) == %@", argument)]
		case .isInArray(let array):
			return [("\(attribute) IN %@", array)]
		case .haveAtLeastOneOf( let argument):
			// If the arguments aren't an array, then the query is differnt
			guard let args = argument as? [Any] else {
				return [("ANY \(attribute) == %@", argument)]
			}
			switch args.count {
			case 0:
				return [("\(attribute).@count == 0", nil)]
			default:
				return [("ANY \(attribute) IN %@", args)]
			}

		case .haveAllOf(let argument):
			guard let args = argument as? [Any] else {
				return [("ANY \(attribute) == %@", argument)]
			}
			switch args.count {
			case 0:
				return [("\(attribute).@count == 0", nil)]
			case 1:
				return [("ANY \(attribute) IN %@", args)]
			default:
				var outStrings: [(String, Any?)] = []
				for arg in args {
					outStrings.append(("SUBQUERY(\(attribute), $att, $att == %@).@count == 1", arg))
				}
				return outStrings
			}
		}
	}
	// swiftlint:enable cyclomatic_complexity

	public func predicate() -> NSPredicate {
		var strings: [String] = []
		var argsArray: [Any] = []
		if let queries = self.constructQuery() {
			for query in queries {
				strings.append(query.0)
				if let args = query.1 {
					argsArray.append(args)
				}
			}
		}
		return NSPredicate(format: strings.joined(separator: " AND "), argumentArray: argsArray.isEmpty ? nil : argsArray)
	}

	public func and( _ search: SearchFor ) -> PredicateComposer {
		return PredicateComposer([self, search], combinedWith: .and)
	}
	public func or( _ search: SearchFor ) -> PredicateComposer {
		return PredicateComposer([self, search], combinedWith: .or)
	}
}
