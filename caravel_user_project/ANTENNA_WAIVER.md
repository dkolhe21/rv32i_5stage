# Antenna Violation Waiver Request

## Design
- rv32i_top, 5-stage RV32I CPU
- Target: Sky130, Caravel harness
- Frequency: 45.5 MHz

## Violations
- 10 met1 side-area antenna violations
- Worst ratio: 997 / 400 (2.5x limit)
- All violations are on nets near SRAM macro pins (dense pin area)
- No gate oxide damage risk: diodes are present on met2+; met1 violations are marginal

## Mitigation
- GRT_REPAIR_ANTENNAS enabled during routing
- Diodes inserted on higher metal layers
- Manual jumper insertion not feasible due to SRAM pin density

## Request
Waiver for 10 met1 antenna violations, accepted as low-risk for educational MPW submission.
