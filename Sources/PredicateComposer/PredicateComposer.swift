import CoreData

public struct PredicateComposer {

	// Disabling Swift Lint as these enum names are namespaced to PredicateComposer and accurately
	// describe how they combine database searches using commonly understood language. 
	// swiftlint:disable identifier_name
	public enum SearchCombiner: CustomStringConvertible {
		case and
		case or

		public var description: String {
			switch self {
			case .and:
				return " AND "
			case .or:
				return " OR "
			}
		}
	}
	// swiftlint:enable identifier_name

	struct Group {
		let searches: [SearchFor]
		let searchCombiner: SearchCombiner
	}
	let groups: [Group]

	var string: String = ""
	var arguments: [Any] = []

	public init() {
		self.groups = []
	}

	public init( _ search: SearchFor ) {
		self.groups = [Group(searches: [search], searchCombiner: .and)]
	}

	public init( _ searches: [SearchFor], combinedWith: SearchCombiner ) {
		self.groups = [Group(searches: searches, searchCombiner: combinedWith)]
	}
	init( _ groups: [Group] ) {
		self.groups = groups
	}

	public func predicate() -> NSPredicate? {
		if groups.isEmpty { return nil }
		let predString = self.predicateString()
		return NSPredicate(format: predString.0, argumentArray: predString.1)
	}

	func predicateString() -> (String, [Any]) {
		var predicateString = ""
		var args: [Any] = []

		for group in groups.reversed() {
			var groupStrings: [String] = []
			for search in group.searches {
				if let searchStrings = search.constructQuery() {
					var stringArray: [String] = []
					for searchString in searchStrings {
						stringArray.append(searchString.0)
						if let searchArgs = searchString.1 {
							args.append(searchArgs)
						}
					}
					groupStrings.append(stringArray.joined(separator: " AND "))
				}
			}
			if groupStrings.isEmpty {
				continue
			}

			if predicateString.isEmpty {
				predicateString = "(" + groupStrings.joined(separator: group.searchCombiner.description) + ")"
			} else {
				predicateString = "(" + groupStrings.joined(separator: group.searchCombiner.description) + group.searchCombiner.description + predicateString + ")"
			}
		}
		return (predicateString, args)
	}

	func addNew( _ search: SearchFor, with combiner: SearchCombiner ) -> PredicateComposer {
		if let group = self.groups.last {
			var newGroups = Array(groups.dropLast())
			var searches = group.searches

			if group.searchCombiner == combiner {
				searches.append(search)
				let group = Group(searches: searches, searchCombiner: combiner)
				newGroups.append(group)
				return PredicateComposer(Array(newGroups))
			} else {
				var newSearches: [SearchFor] = []
				if let newSearch = searches.last {
					newSearches = [newSearch, search]
				} else {
					newSearches = [search]
				}
				let previousSearches = searches.dropLast()
				let previousGroup = Group(searches: Array(previousSearches), searchCombiner: group.searchCombiner)
				let group = Group(searches: newSearches, searchCombiner: combiner)
				newGroups.append(previousGroup)
				newGroups.append(group)
				return PredicateComposer(newGroups)
			}
		} else {
			return PredicateComposer([search], combinedWith: .and)
		}
	}


	public func and( _ search: SearchFor ) -> PredicateComposer {
		addNew(search, with: .and)
	}

	public func or( _ search: SearchFor ) -> PredicateComposer {
		addNew(search, with: .or)
	}

}
// PredicateComposer(SearchFor(X)).and(SearchFor(Y))
// X AND Y

// PredicateComposer(SearchFor(X)).and(.or([SearchFor(A), SearchFor(B)])
// X AND (A or B)

// PredicateComposer(.and([SearchFor(X), SearchFor(Y)])).or(.and([SearchFor(A), SearchFor(B)])
// (X AND Y) OR (A AND B)

// PredicateComposer( SearchFor(X) ).and( SearchFor(A).or(SearchFor(B).and(.and(SearchFor(F).or(SearchFor(G)))


