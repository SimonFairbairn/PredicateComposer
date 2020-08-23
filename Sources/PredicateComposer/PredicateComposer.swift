import CoreData

public enum PredicateType : String {
	case contains
	case containsCaseInsentive
	case equals
	case inArray
	case manyToManySearch
}

public enum SearchType : String {
	case or
	case and
}

public protocol PredicateComposing {
	func requirements() -> (predicates: [PredicateStruct], combination: SearchType)?
}


public struct PredicateStruct {
	let attribute : String
	let predicateType : PredicateType
	let arguments : Any?
	let searchType : SearchType
	
	public init( attribute : String, predicateType : PredicateType, arguments : Any? = nil, searchType : SearchType = .and) {
		self.attribute = attribute
		self.predicateType = predicateType
		self.arguments = arguments
		self.searchType = searchType
	}
	
	internal func constructQuery() -> [(String, Any?)]? {
		switch self.predicateType {
		case .contains:
			return (self.arguments == nil) ? nil : [("\(attribute) CONTAINS %@", self.arguments)]
		case .containsCaseInsentive:
			return [("\(attribute) CONTAINS[c] %@", self.arguments)]
		case .equals:
			return [("\(attribute) == %@", self.arguments)]
		case .inArray:
			return [("\(attribute) IN %@", self.arguments)]
		case .manyToManySearch:
			switch self.searchType {
			case .or:
				return [("SUBQUERY(\(attribute), $att, $att IN %@).@count != 0", self.arguments)]
			case .and:
				guard let args = self.arguments as? [Any] else {
					return nil
				}
				switch args.count {
				case 1:
					return [("\(attribute).@count == 1 AND SUBQUERY(\(attribute), $tag, $tag == %@).@count == 1", self.arguments)]
				default:
					var outStrings : [(String, Any?)] = []
					for arg in args {
						outStrings.append(("SUBQUERY(\(attribute), $tag, $tag == %@).@count == 1", arg))
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
		if !composition.isEmpty {
			finalPredicateString = "("
			for comp in composition {
				if comp.searchType != currentSearchType {
					
					// This is the first time through, so no need to join
					if finalPredicateString != "(" {
						finalPredicateString = predicateString.joined(separator: " \(currentSearchType.rawValue.uppercased()) ")
						finalPredicateString += ") AND ("
					}
					predicateString.removeAll()
					currentSearchType = comp.searchType
				}
				
				for req in comp.predicates {
					guard let queries = req.constructQuery() else {
						continue
					}
					for string in queries  {
						if let existentOptions = string.1 {
							argumentArray.append(existentOptions)
						}
						predicateString.append(string.0)
					}
				}
			}
			finalPredicateString += predicateString.joined(separator: " \(currentSearchType.rawValue.uppercased()) ")
			finalPredicateString += ")"
		}
		
		
		if !finalPredicateString.isEmpty {
			return NSPredicate(format: finalPredicateString, argumentArray: argumentArray)
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
			
			if validReq.combination != current.searchType {
				self.composition.append(current)
				current = PredicateComposition(searchType: validReq.combination, predicates: [])
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
		
		let comp = PredicateComposition(searchType: validReq.combination, predicates: validReq.predicates)
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
