import std/times
import ../basics
import ../simulator

suite "Validator Network Performance":

  test "a network of 20 validators reaches consensus within 1 second":
    # TODO: 100 validators
    let simulator = NetworkSimulator.init(20)
    discard !simulator.exchangeProposals()
    simulator.nextRound()
    discard !simulator.exchangeProposals()
    simulator.nextRound()
    let start = now()
    discard !simulator.exchangeProposals()
    let finish = now()
    check finish - start < initDuration(seconds = 1)
