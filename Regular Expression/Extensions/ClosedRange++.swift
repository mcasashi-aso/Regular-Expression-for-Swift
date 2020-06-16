//
//  ClosedRange++.swift
//  Regular Expression
//
//  Created by Masashi Aso on 2020/06/16.
//  Copyright © 2020 Masashi Aso. All rights reserved.
//

extension ClosedRange {
    init(at point: Bound) {
        self = point...point
    }
}
