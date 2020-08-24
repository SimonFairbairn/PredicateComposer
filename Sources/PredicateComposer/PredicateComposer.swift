import CoreData

public enum PredicateType : String {
	case contains
	case containsCaseInsensitive
	case equals
	case inArray
	case manyToManySearch
	case beginsWithCaseInsensitive
}

public enum SearchType : String {
	case or
	case and
}

public struct PredicateComposer {
	let predicates : [PredicateStruct]
	let combinedWith : SearchType
	
	public init( predicates : [PredicateStruct], combinedWith : SearchType = .or) {
		self.predicates = predicates
		self.combinedWith = combinedWith
	}
}

public protocol PredicateComposing {
	func requirements() -> PredicateComposer?
}


public struct PredicateStruct {
	let attribute : String
	let predicateType : PredicateType
	let arguments : Any?
	let searchType : SearchType
	
	public init( attribute : String, predicateType : PredicateType, arguments : Any? = nil, searchType : SearchType = .or) {
		self.attribute = attribute
		self.predicateType = predicateType
		self.arguments = arguments
		self.searchType = searchType
	}
	
	internal func constructQuery() -> [(String, Any?)]? {
		switch self.predicateType {
		case .contains:
			return (self.arguments == nil) ? nil : [("\(attribute) CONTAINS %@", self.arguments)]
		case .containsCaseInsensitive:
			return [("\(attribute) CONTAINS[c] %@", self.arguments)]
		case .beginsWithCaseInsensitive:
			return [("\(attribute) BEGINSWITH[c] %@", self.arguments)]
		case .equals:
			return [("\(attribute) == %@", self.arguments)]
		case .inArray:
			return [("\(attribute) IN %@", self.arguments)]
		case .manyToManySearch:
			// If the arguments aren't an array, then the query is differnt
			guard let args = self.arguments as? [Any] else {
				return [("ANY \(attribute) == %@", self.arguments)]
			}
			switch self.searchType {
			case .or:
				return [("ANY \(attribute) IN %@", self.arguments)]
			case .and:
				switch args.count {
				case 1:
					return [("ANY \(attribute) IN %@", self.arguments)]
				default:
					var outStrings : [(String, Any?)] = []
					for arg in args {
						outStrings.append(("SUBQUERY(\(attribute), $att, $att == %@).@count == 1", arg))
					}
					return outStrings
				}
			}
			
		}
	}
}

public struct CoreDataPredicateComposer<T : NSManagedObject> {
	
	struct PredicateComposition {
		let searchType : SearchType
		var predicates : [PredicateStruct]
	}
	
	private var composition : [PredicateComposition] = []
	
	public var predicate : NSPredicate? {
		var predicateString : [String] = []
		var argumentArray : [Any] = []

		var currentSearchType : SearchType = .and
		var finalPredicateString = ""
		var predicateArray : [String] = []
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
					var innerPredicateStrings : [String] = []
					for string in queries  {
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
	
	
	public init( requirements : [PredicateComposing] = []) {
		
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
	
	mutating public func remove( _ requirement : PredicateComposing ) {
//		self.remove(requirement.requirements())
	}
	
	mutating private func remove( _ predicates : [PredicateStruct] ) {
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
	
	mutating public func add( _ requirement : PredicateComposing ) {
		
		guard let validReq = requirement.requirements() else {
			return
		}
		
		let comp = PredicateComposition(searchType: validReq.combinedWith, predicates: validReq.predicates)
		self.composition.append(comp)

	}
	
	public func dictionaryFetchRequest( entityName : String ) -> NSFetchRequest<NSFetchRequestResult> {
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
