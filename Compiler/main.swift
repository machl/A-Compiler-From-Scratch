//
//  main.swift
//  Compiler
//

import Foundation

// lexer (tokenizer) -> parser -> code generator

let source = try! String(contentsOfFile: CommandLine.arguments[1])

enum TokenType: String {
    case def = "\\bdef\\b"
    case end = "\\bend\\b"
    case identifier = "\\b[a-zA-Z]+\\b"
    case integer = "\\b[0-9]+\\b"
    case oparen = "\\("
    case cparen = "\\)"
    case comma = ","
    
    static let ordered: [TokenType] = [.def, .end, .identifier, .integer, .oparen, .cparen, .comma]
}

struct Token {
    let type: TokenType
    let value: String
}

class Tokenizer {
    private var code: String
    
    init(_ code: String) {
        self.code = code
    }
    
    func tokenize() -> [Token] {
        var tokens: [Token] = []
        while !code.isEmpty {
            tokens.append(tokenizeOneToken())
            code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return tokens
    }
    
    private func tokenizeOneToken() -> Token {
        for type in TokenType.ordered {
            let regex = try! NSRegularExpression(pattern: "\\A(\(type.rawValue))")
            if let firstMatch = regex.firstMatch(in: code, options: [], range: NSRange(code.startIndex..., in: code)) {
                let value = String(code[Range(firstMatch.range, in: code)!])
                code = String(code.dropFirst(firstMatch.range.upperBound))
                return Token(type: type, value: value)
            }
        }
        
        fatalError("Couldn't match token on \(code)")
    }
}

protocol Node {}

struct DefNode: Node {
    let name: String
    let argNames: [String]
    let body: Node
}

struct IntegerNode: Node {
    let value: Int
}

struct CallNode: Node {
    let name: String
    let argExprs: [Node]
}

struct VarRefNode: Node {
    let value: String
}

class Parser {
    private var tokens: [Token]
    
    init(_ tokens: [Token]) {
        self.tokens = tokens
    }
    
    func parse() -> Node {
        return parseDef()
    }
    
    private func parseDef() -> DefNode {
        consume(.def)
        let name = consume(.identifier).value
        let argNames = parseArgNames()
        let body = parseExpr()
        consume(.end)
        return DefNode(name: name, argNames: argNames, body: body)
    }
    
    private func parseArgNames() -> [String] {
        var argNames: [String] = []
        consume(.oparen)
        
        // i(,i)+
        if peek(.identifier) {
            argNames.append(consume(.identifier).value)
            while peek(.comma) {
                consume(.comma)
                argNames.append(consume(.identifier).value)
            }
        }
        
        consume(.cparen)
        return argNames
    }
    
    private func parseExpr() -> Node {
        if peek(.integer) {
            return parseInteger()
        } else if peek(.identifier) && peek(.oparen, offset: 1) {
            return parseCall()
        } else {
            return parseVarRef()
        }
    }
    
    private func parseInteger() -> IntegerNode {
        return IntegerNode(value: Int(consume(.integer).value)!)
    }
    
    private func parseCall() -> CallNode {
        let name = consume(.identifier).value
        let argExprs = parseArgExprs()
        return CallNode(name: name, argExprs: argExprs)
    }
    
    private func parseArgExprs() -> [Node] {
        var argExprs: [Node] = []
        consume(.oparen)
        if !peek(.cparen) {
            argExprs.append(parseExpr())
            while peek(.comma) {
                consume(.comma)
                argExprs.append(parseExpr())
            }
        }
        consume(.cparen)
        return argExprs
    }
    
    private func parseVarRef() -> VarRefNode {
        return VarRefNode(value: consume(.identifier).value)
    }
    
    @discardableResult
    private func consume(_ type: TokenType) -> Token {
        let token = tokens.removeFirst()
        if token.type == type {
            return token
        }
        fatalError("Expected token type .\(type) but got .\(token.type)")
    }
    
    private func peek(_ expectedType: TokenType, offset: Int = 0) -> Bool {
        return tokens[offset].type == expectedType
    }
}

class Generator {
    func generate(_ node: Node) -> String {
        switch node {
        case let node as DefNode:
            return String(format: "function %@(%@) { return %@ };",
                          node.name,
                          node.argNames.joined(separator: ","),
                          generate(node.body)) // recursive generate call
        case let node as CallNode:
            return String(format: "%@(%@)",
                          node.name,
                          node.argExprs.map { generate($0) }.joined(separator: ","))
        case let node as VarRefNode:
            return node.value
        case let node as IntegerNode:
            return String(node.value)
        default:
            fatalError("Unexpected node type: \(type(of: node))")
        }
    }
}


let tokens = Tokenizer(source).tokenize()
//tokens.forEach({
//    print("Token(type: .\($0.type), value: \"\($0.value)\")")
//})

let tree = Parser(tokens).parse()
//print(tree)

let generated = Generator().generate(tree)

let RUNTIME =
    """
    function add(x, y) { return x + y };
    """

let TEST =
    """
    console.log(f(1,2));
    """

print(
    [RUNTIME, generated, TEST]
        .joined(separator: "\n")
)

// Run it with:
// $ swift main.swift test.src | node
