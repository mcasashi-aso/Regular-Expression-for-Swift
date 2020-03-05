//
//  Concat.swift
//  Regular Expression
//
//  Created by Masashi Aso on 2020/03/04.
//  Copyright © 2020 Masashi Aso. All rights reserved.
//

struct Concat: Node {
    
    var node1, node2: Node
    
    init(_ node1: Node, _ node2: Node) {
        self.node1 = node1
        self.node2 = node2
    }
    
    func assemble(_ context: inout Context) -> NFAFragment {
        let frag1 = node1.assemble(&context)
        let frag2 = node2.assemble(&context)
        var frag = NFAFragment.compose(frag1, frag2)
        
        for state in frag1.accepts {
            frag.connect(from: state, to: frag2.start, with: nil)
        }
        
        frag.start = frag1.start
        frag.accepts = frag2.accepts
        
        return frag
    }
    
    func toString() -> String { node1.toString() + node2.toString() }
}
