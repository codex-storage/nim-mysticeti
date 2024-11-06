import ./basics
import ./simulator

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
