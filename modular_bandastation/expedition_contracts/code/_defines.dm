// Order states.
/// Waiting for the corps to take or turn it down.
#define EXPEDITION_CONTRACT_OFFERED "offered"
/// Taken; its current step is live.
#define EXPEDITION_CONTRACT_ACTIVE "active"
/// Every step done and the reward paid.
#define EXPEDITION_CONTRACT_DONE "done"
/// Turned down while offered, or dropped after it was taken.
#define EXPEDITION_CONTRACT_DECLINED "declined"
/// Withdrawn because nobody took it in time.
#define EXPEDITION_CONTRACT_EXPIRED "expired"
/// The thing it was for is gone; only side tasks end this way.
#define EXPEDITION_CONTRACT_FAILED "failed"

// Pacing; starting values from the 2026-11-12 design, tune by how often offers lapse untaken.
/// Offers opened when the round starts.
#define EXPEDITION_CONTRACTS_AT_START 2
/// Time between waves of new offers.
#define EXPEDITION_CONTRACT_WAVE_DELAY (30 MINUTES)
/// Offers and taken orders open at once; a wave adds nothing past this.
#define EXPEDITION_CONTRACTS_MAX_OPEN 3
/// An offer nobody takes is withdrawn after this.
#define EXPEDITION_CONTRACT_OFFER_LIFETIME (30 MINUTES)
/// Chance an order comes with a side task; raise it if side tasks are rare and wanted.
#define EXPEDITION_SIDE_CHANCE 50
