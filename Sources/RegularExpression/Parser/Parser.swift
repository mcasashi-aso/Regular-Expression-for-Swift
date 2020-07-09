
struct Parser {
    var lexer: Lexer
    var looking: Token!
    
    init(lexer: Lexer) {
        self.lexer = lexer
        self.looking = nil
        self.move()
    }
    
    mutating func matchKind(of tag: Token) throws {
        guard tag.isSameKind(of: self.looking) else {
            switch tag {
            case .character, .dot, .union, .star, .plus, .question,
                 .lParen, .lSquareBracket, .hyphen, .lCurlyBracket, .EOF:
                throw ParseError.other
            case .rParen:         throw ParseError.missing(.paren)
            case .rSquareBracket: throw ParseError.missing(.square)
            case .rCurlyBracket:  throw ParseError.missing(.curly)
            }
        }
        self.move()
    }
    
    mutating func move() {
        self.looking = self.lexer.scan()
    }
}

extension Parser {
    enum ParseError: Error, CustomStringConvertible {
        case missing(BracketType)
        case number
        case other
        
        enum BracketType {
            case curly, square, paren
            var character: Character {
                switch self {
                case .curly:  return "}"
                case .square: return "]"
                case .paren:  return ")"
                }
            }
        }
        
        var description: String {
            switch self {
            case .missing(let b): return "Missing `\(b.character)`"
            case .number: return "{} must be {count} or {start,end}"
            case .other:  return "Syntax Error"
            }
        }
    }
}

extension Parser {
    
    /// 規則F: `a`, `(ab|c*)`
    ///
    /// 括弧で囲まれたsubExpressionかCHARACTER
    ///
    /// `factor -> ( subExpression ) | CHARACTER`
    mutating func factor() throws -> Node {
        switch self.looking {
        case .lParen:
            // `(` subExpression `)`
            try self.matchKind(of: .lParen)
            let node = try self.subExpression()
            try self.matchKind(of: .rParen)
            return node
        case .lSquareBracket: // [ CHARACTER... ]
            try self.matchKind(of: .lSquareBracket)
            var nodes = [Node]()
            
            while looking != .rSquareBracket {
                let character = try looking.character !! ParseError.missing(.square)
                nodes.append(.character(character))
                self.move()
                
                guard case .hyphen = looking else { continue }
                try self.matchKind(of: .hyphen)
                if let end = looking.character {
                    nodes.append(.character(.range(character...end)))
                } else {
                    nodes.append(.character(Token.hyphen.character!))
                }
            }
            
            try self.matchKind(of: .rSquareBracket)
            return Node.union(nodes)
        case .dot:
            try self.matchKind(of: .dot)
            return .character(.any)
        case .hyphen:
            try self.matchKind(of: .hyphen)
            return .character(Token.hyphen.character!)
        case .character(let char):
            try self.matchKind(of: .character(" "))
            return .character(char)
        default:
            throw ParseError.other
        }
    }
    
    /// 規則E: `a*`, `a`, `(ab)*`
    ///
    /// factor、もしくはfactorに*をつけたもの
    ///
    /// `star -> (factor *) | factor`
    mutating func star() throws -> Node {
        let node = try self.factor()
        switch self.looking {
        case .plus:
            try self.matchKind(of: .plus)
            return Node.plus(node)
        case .star:
            try self.matchKind(of: .star)
            return Node.star(node)
        case .question:
            try self.matchKind(of: .question)
            return Node.question(node)
        case .lCurlyBracket:
            try self.matchKind(of: .lCurlyBracket)
            let string = try self.sequence().string
            try self.matchKind(of: .rCurlyBracket)
            let numbers = try string.filter { $0 != " " }.split(separator: ",")
                .map { try UInt(String($0)) !! ParseError.number }
            
            switch numbers.count {
            case 1:     // {3}
                return Node.repeat(node, ClosedRange(at: numbers[0]))
            case 2:     // {1, 3}
                let start = numbers[0], end = numbers[1]
                guard start <= end else { throw ParseError.number }
                return Node.repeat(node, start...end)
            default:
                throw ParseError.number
            }
        default:
            return node
        }
    }
    
    /// 規則D: `ab`, `a*bc`, `(ab)*cd`
    ///
    /// starを一個以上繋げたもの
    ///
    /// `sequence -> subSequence | null`
    mutating func sequence() throws -> Node {
        let tokens: [Token] = [.lParen, .character(" "), .dot, .lSquareBracket, .lCurlyBracket, .hyphen]
        if tokens.contains(where: { $0.isSameKind(of: self.looking) }) {
            return try self.subSequence()
        } else {
            return .character(.null)
        }
    }
    
    /// 規則C: `(ab)*cd`, ``
    ///
    /// 文字列か空文字
    ///
    /// `subSequence -> star (subSequence | star)`
    mutating func subSequence() throws -> Node {
        var nodes = [try self.star()]
        let tokens: [Token] = [.lParen, .character(" "), .dot, .lSquareBracket, .lCurlyBracket, .hyphen]
        while tokens.contains(where: { $0.isSameKind(of: self.looking) }) {
            nodes.append(try self.subSequence())
        }
        return .concat(nodes)
    }
    
    /// 規則B: `a|b`, `a*bc|(ab)*cd|`
    ///
    /// sequenceを`|`で一個以上繋げたもの
    ///
    /// `subExpression -> (sequence | subExpression) | sequence`
    mutating func subExpression() throws -> Node {
        var nodes = [try self.sequence()]
        while case .union = looking {
            try self.matchKind(of: .union)
            nodes.append(try self.subExpression())
        }
        return .union(nodes)
    }
    
    /// 規則A: `a*bc|(ab)*cd|` + EOF
    /// 
    /// 末尾にEOFがある
    ///
    /// `expression -> subExpression + EOF`
    mutating func expression() throws -> NondeterministicFiniteAutomaton {
        let node = try self.subExpression()
        try self.matchKind(of: .EOF)
        
        var context = Context()
        let fragment = node.assemble(&context)
        return fragment.build()
    }
}
