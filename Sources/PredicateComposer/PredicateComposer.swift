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
	case attribute(String)
	case relationshipWithEntityNamed(String)
	case entityRelationshipWithAttribute(String, String)
}

public struct PredicateComposer {

	// Disabling Swift Lint as these enum names are namespaced to PredicateComposer and accurately
	// describe how they combine database searches using commonly understood language. 
	// swiftlint:disable identifier_name
	public indirect enum SearchGroupCombiner {
		case and([SearchFor], SearchGroupCombiner? = nil)
		case or([SearchFor], SearchGroupCombiner? = nil)
	}
	// swiftlint:enable identifier_name

	var string: String = ""
	var arguments: [Any] = []
	public init( _ combinations: SearchGroupCombiner...) {
		for combo in combinations {
			self.parse(combo)
		}
	}

	public init( _ search: SearchFor ) {
		if let queries = search.constructQuery() {
			for query in queries {
				self.string = query.0
				if let args = query.1 {
					self.arguments.append(args)
				}
			}
		}
	}

	mutating func parseSearches( _ searches: [SearchFor] ) -> [String] {
		var strings: [String] = []
		for search in searches {
			var innerStrings: [String] = []
			if let queries = search.constructQuery() {
				for query in queries {
					innerStrings.append(query.0)
					if let args = query.1 {
						self.arguments.append(args)
					}
				}
			}
			strings.append(innerStrings.joined(separator: " AND "))
		}
		return strings
	}

	mutating func parse( _ combo: SearchGroupCombiner ) {
		switch combo {
		case .and(let searches, let children):
			self.string += "("
			let strings = self.parseSearches(searches)
			self.string += strings.joined(separator: " AND ")
			if let child = children {
				self.string += " AND "
				self.parse(child)
			}

			self.string += ")"
		case .or(let searches, let children):
			self.string += "("
			let strings = self.parseSearches(searches)
			self.string += strings.joined(separator: " OR ")
			if let child = children {
				self.string += " OR "
				self.parse(child)
			}

			self.string += ")"
		}
	}

	func predicate() -> NSPredicate? {
		guard !self.string.isEmpty else { return nil }
		return NSPredicate(format: self.string, argumentArray: self.arguments)
	}

}
