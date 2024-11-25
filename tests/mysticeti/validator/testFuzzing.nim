import ../basics
import ../fuzzing
import ../simulator
import ../scenarios
import mysticeti

suite "Validator Network Fuzzing (seed: " & $fuzzing.seed & ")":

  var simulator: NetworkSimulator

  setup:
    simulator = NetworkSimulator.init()

  test "all validators emit blocks in the same sequence":
    discard !simulator.randomScenario()
    let sequences = simulator.validators.mapIt(toSeq(it.committed()))
    for sequence in sequences[1..^1]:
      check sequence == sequences[0]
