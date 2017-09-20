//
//  BWNavigatableTask.swift
//  Beiwe
//
//  Created by Keary Griffin on 11/28/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

class BWNavigatableTask: ORKNavigableOrderedTask {
    override func step(after step: ORKStep?, with result: ORKTaskResult) -> ORKStep? {
        log.info("stepAfterStep for \(step?.identifier)");
        return super.step(after: step, with: result);
    }

    override func step(before step: ORKStep?, with result: ORKTaskResult) -> ORKStep? {
        log.info("stepBeforeStep for \(step?.identifier)");
        return super.step(before: step, with: result);
    }
}
