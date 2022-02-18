import CoreData

public enum PredicateType {
	case contains(String?)
	case containsCaseInsensitive(String?)
	case beginsWithCaseInsensitive(String?)
	case equals(Any?)
	case isInArray([Any])
	case haveAtLeastOneOf( Any)
	case haveAllOf( Any )
	case isTrue
	case isFalse
}

public enum Match {
	case entity
	@available(*, deprecated, message: "Use `relationshipWithEntityNamed` instead")
	case entityNamed(String)
	@available(*, deprecated, message: "Use `attribute` instead")
	case entitiesWithAttribute(String)

	case attribute(String)
	case relationshipWithEntityNamed(String)
	case entityRelationshipWithAttribute(String, String)
}

public enum SearchType: String {
	case or
	case and
}

public struct PredicateComposer {
	let predicates: [SearchFor]
	let combinedWith: SearchType

	public init( predicates: [SearchFor], combinedWith: SearchType = .or) {
		self.predicates = predicates
		self.combinedWith = combinedWith
	}
}

public struct SearchComposer {
	let searches: [SearchFor]
	let combinedWith: SearchType

	public init( searches: [SearchFor], combinedWith: SearchType = .or) {
		self.searches = searches
		self.combinedWith = combinedWith
	}
}

public protocol PredicateComposing {
	func requirements() -> PredicateComposer?
}

public struct SearchFor {
	let attribute: String
	let predicateType: PredicateType
	let arguments: Any?

	public init( _ attribute: Match, that predicateType: PredicateType, arguments: Any? = nil) {
		switch attribute {
		case .entity:
			self.attribute = "self"
		case .entityNamed(let string):
			self.attribute = string
		case .entitiesWithAttribute(let string):
			self.attribute = string
		case .attribute(let attribute):
			self.attribute = attribute
		case .relationshipWithEntityNamed(let entity):
			self.attribute = entity
		case .entityRelationshipWithAttribute(let obj, let attribute):
			self.attribute = "\(obj).\(attribute)"
		}
		self.predicateType = predicateType
		self.arguments = arguments
	}

	internal func constructQuery() -> [(String, Any?)]? {
		switch self.predicateType {
		case .isTrue:
			return [("\(attribute) == true", nil)]
		case .isFalse:
			return [("\(attribute) == false", nil)]
		case .contains(let argument):
			return (argument == nil) ? nil : [("\(attribute) CONTAINS %@", argument)]
		case .containsCaseInsensitive(let argument):
			return (argument == nil) ? nil : [("\(attribute) CONTAINS[c] %@", argument)]
		case .beginsWithCaseInsensitive(let argument):
			return (argument == nil) ? nil : [("\(attribute) BEGINSWITH[c] %@", argument)]
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
}

public extension NSManagedObject {

	static func generatePredicate( from searches: [SearchComposer] ) -> NSPredicate? {
		var current = PredicateComposition(searchType: .and, predicates: [])

		for req in searches {
			if req.combinedWith != current.searchType {
				current = PredicateComposition(searchType: req.combinedWith, predicates: [])
			}
			current.predicates.append(contentsOf: req.searches)
		}

		return self.predicate(with: [current] )
	}

	static func generatePredicate( _ search: SearchFor ) -> NSPredicate? {
		let searchComposer = SearchComposer(searches: [search])
		return Self.generatePredicate(from: [searchComposer])
	}

	static func predicate( with composition: [PredicateComposition]) -> NSPredicate? {
		var predicateString: [String] = []
		var argumentArray: [Any] = []

		var currentSearchType: SearchType = .and
		var finalPredicateString = ""
		var predicateArray: [String] = []
		if !composition.isEmpty {
			for comp in composition {
				if comp.searchType != currentSearchType {
					if !finalPredicateString.isEmpty {
						finalPredicateString = predicateString.joined(separator: " \(currentSearchType.rawValue.uppercased()) ")
						predicateArray.append(finalPredicateString)
					}
					predicateString.removeAll()
					currentSearchType = comp.searchType
				}

				for req in comp.predicates {
					guard let queries = req.constructQuery() else {
						continue
					}
					var innerPredicateStrings: [String] = []
					for string in queries {
						if let existentOptions = string.1 {
							argumentArray.append(existentOptions)
						}
						innerPredicateStrings.append(string.0)
					}
					if !innerPredicateStrings.isEmpty {
						predicateString.append("(" + innerPredicateStrings.joined(separator: " AND ") + ")")
					}

				}
			}
			finalPredicateString += predicateString.joined(separator: " \(currentSearchType.rawValue.uppercased()) ")
			predicateArray.append(finalPredicateString)
		}

		let validPredicates = predicateArray.filter({ !$0.isEmpty }).map({ "(\($0))"  }).joined(separator: " AND ")

		if !validPredicates.isEmpty {
			return NSPredicate(format: validPredicates, argumentArray: argumentArray)
		} else {
			return nil
		}
	}

}

public	struct PredicateComposition {
	let searchType: SearchType
	var predicates: [SearchFor]
}

public struct CoreDataPredicateComposer<T: NSManagedObject> {

	private var composition: [PredicateComposition] = []

	public var predicate: NSPredicate? {
		return T.predicate(with: composition)
	}

	public init( requirements: [PredicateComposing] = []) {

		guard !requirements.isEmpty else {
			return
		}
		var current = PredicateComposition(searchType: .and, predicates: [])

		for req in requirements {
			guard let validReq = req.requirements() else {
				continue
			}

			if validReq.combinedWith != current.searchType {
				self.composition.append(current)
				current = PredicateComposition(searchType: validReq.combinedWith, predicates: [])
			}
			current.predicates.append(contentsOf: validReq.predicates)
		}
		self.composition.append(current)
	}

	mutating public func addPredicate( for attribute: Match, type: PredicateType, arguments: Any? = nil ) {
		let newPred = SearchFor(attribute, that: type)
		self.composition.append(PredicateComposition(searchType: .or, predicates: [newPred]))
	}

	mutating public func remove( _ requirement: PredicateComposing ) {
//		self.remove(requirement.requirements())
	}

	mutating private func remove( _ predicates: [SearchFor] ) {
//		for predicate in predicates {
//			guard let finalString = predicate.constructQuery() else {
//				continue
//			}
//			let string = finalString.map({ $0.0 }).joined()
//
//			self.requirements.removeAll(where: { pred in
//				guard let pred = pred.constructQuery() else {
//					return false
//				}
//				return string == pred.map({ $0.0 }).joined()
//			})
//		}
	}

	mutating public func add( _ requirement: PredicateComposing ) {

		guard let validReq = requirement.requirements() else {
			return
		}

		let comp = PredicateComposition(searchType: validReq.combinedWith, predicates: validReq.predicates)
		self.composition.append(comp)

	}

	public func dictionaryFetchRequest( entityName: String ) -> NSFetchRequest<NSFetchRequestResult> {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: T.entity().name! )
		fetchRequest.predicate = self.predicate
		return fetchRequest
	}

	public func fetchRequest() -> NSFetchRequest<T> {
		let fetchRequest = NSFetchRequest<T>(entityName: T.entity().name! )
		fetchRequest.predicate = self.predicate
		return fetchRequest
	}

}
