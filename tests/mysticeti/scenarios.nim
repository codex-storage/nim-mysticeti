import mysticeti
import ./basics
import ./simulator

type SignedBlock = mysticeti.SignedBlock[MockDependencies]
type Transaction = MockTransaction

proc scenarioFigure4*(simulator: NetworkSimulator): ?!seq[seq[SignedBlock]] =
  # replays scenario from figure 4 in the Mysticeti paper
  # https://arxiv.org/pdf/2310.14821v4
  # note: round robin is not applied correctly in the figure from
  # the Mysticeti paper, so this simulation uses different proposer
  # labels from the fourth round
  var proposals: seq[seq[SignedBlock]]
  proposals.add(? simulator.exchangeProposals {
    0: @[0, 1, 2, 3],
    1: @[0, 1],
    2: @[0, 2, 3],
    3: @[1, 2, 3]
  })
  simulator.nextRound()
  proposals.add(? simulator.exchangeProposals {
    0: @[0, 1, 3],
    1: @[0, 1, 3],
    2: @[0, 3],
    3: @[1, 3]
  })
  simulator.nextRound()
  proposals.add(? simulator.exchangeProposals {
    0: @[2, 3, 0, 1],
    1: @[2, 3, 0, 1],

    3: @[2, 3, 0, 1]
  })
  simulator.nextRound()
  proposals.add(? simulator.exchangeProposals {
    2: @[2, 3, 0, 1],
    3: @[3],
    0: @[2, 3, 0, 1],
    1: @[2, 3, 0, 1]
  })
  simulator.nextRound()
  proposals.add(? simulator.exchangeProposals {
    2: @[],
    3: @[2, 3, 0],
    0: @[2, 3, 0],
    1: @[2, 3, 0]
  })
  simulator.nextRound()
  proposals.add(? simulator.exchangeProposals {
    2: @[2, 3, 0, 1],
    3: @[2, 3, 0, 1],
    0: @[2, 3, 0, 1]

  })
  success proposals

proc randomScenario*(simulator: NetworkSimulator): ?!seq[seq[SignedBlock]] =
  var proposals: seq[seq[SignedBlock]]
  let rounds = rand(100)
  for round in 0..<rounds:
    # one validator is allowed to deviate from the protocol
    let deviant = rand(0..<simulator.validators.len)
    var exchanges: seq[(int, seq[int])]
    for proposer in simulator.validators.low..simulator.validators.high:
      # 50% chance of not proposing a block
      if proposer == deviant and rand(100) < 50:
        continue
      var receivers: seq[int]
      for receiver in simulator.validators.low..simulator.validators.high:
        # 50% chance of not sending a block
        if proposer == deviant and rand(100) < 50:
          continue
        receivers.add(receiver)
      exchanges.add( (proposer, receivers) )
    proposals.add(? simulator.exchangeProposals(exchanges))
    simulator.nextRound()
  success proposals
