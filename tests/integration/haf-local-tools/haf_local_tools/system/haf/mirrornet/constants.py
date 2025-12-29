CHAIN_ID: str = "42"
SKELETON_KEY: str = "5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n"

# Block numbers known to contain transactions in the mirrornet block_log.
# Tests use these to verify transaction indexing without depending on
# specific transaction hashes which change when the block_log is regenerated.
BLOCKS_WITH_TRANSACTIONS = [1092, 999892, 4500000, 4500001, 5000000]

WITNESSES_5M: list[str] = [
    "rabbit-70",
    "kushed",
    "delegate.lafona",
    "wackou",
    "complexring",
    "jesta",
    "xeldal",
    "riverhead",
    "clayop",
    "steemed",
    "smooth.witness",
    "ihashfury",
    "joseph",
    "datasecuritynode",
    "boatymcboatface",
    "steemychicken1",
    "roadscape",
    "pharesim",
    "abit",
    "blocktrades",
    "arhag",
    "bitcube",
    "witness.svk",
    "gxt-1080-sc-0003",
    "steve-walschot",
    "bhuz",
    "liondani",
    "rabbit-63",
    "pfunk",
]

WITNESSES_2M: list[str] = [
    "abderus",
    "xeldal",
    "roadscape",
    "abit",
    "pharesim",
    "kushed",
    "au1nethyb1",
    "dele-puppy",
    "silversteem",
    "steemed",
    "smooth.witness",
    "complexring",
    "masteryoda",
    "nextgencrypto",
    "arhag",
    "riverhead",
    "bitcube",
    "blocktrades",
    "witness.svk",
    "clayop",
    "steempty",
]
