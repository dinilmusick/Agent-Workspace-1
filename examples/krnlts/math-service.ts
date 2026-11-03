import type {
  FunctionalityDefinition,
  ServiceDefinition,
} from "@ultrst-armada/krnlts"

import { createServiceFacade } from "@ultrst-armada/krnlts"

type AddInput = {
  a: number
  b: number
}

type MathState = {
  calculationCount: number
}

const addFunctionality: FunctionalityDefinition<
  AddInput,
  number,
  MathState
> = {
  id: "add",
  name: "Add",

  execute({ a, b }, context) {
    return a + b
  },
}

const definition: ServiceDefinition<MathState> = {
  id: "example-math",
  name: "Example Math Service",
  version: "1.0.0",

  operations: {
    add: {
      id: "add",
      name: "Add",
      handler: ({ a, b }: AddInput) => a + b,
    },
  },

  state: {
    initial: {
      calculationCount: 0,
    },
  },
}

export const mathService = createServiceFacade({
  id: definition.id,
  name: definition.name,
  version: definition.version,
  definition,
  functionalities: {
    add: addFunctionality,
  },
})

// Reading guide:
//
// definition       -> CONTRACT: what the service exposes
// addFunctionality -> BEHAVIOR: what "add" does
// createServiceFacade(...) -> COMPOSITION / EXECUTION BOUNDARY
// mathService      -> PUBLIC RUNTIME SERVICE
