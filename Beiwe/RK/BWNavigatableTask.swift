//
//  BWNavigatableTask.swift
//  Beiwe
//
//  Created by Keary Griffin on 11/28/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

class BWNavigatableTask: ORKNavigableOrderedTask {
    override func stepAfterStep(step: ORKStep?, withResult result: ORKTaskResult) -> ORKStep? {
        log.info("stepAfterStep for \(step?.identifier)");
        return super.stepAfterStep(step, withResult: result);
    }

    override func stepBeforeStep(step: ORKStep?, withResult result: ORKTaskResult) -> ORKStep? {
        log.info("stepBeforeStep for \(step?.identifier)");
        return super.stepBeforeStep(step, withResult: result);
    }
}
