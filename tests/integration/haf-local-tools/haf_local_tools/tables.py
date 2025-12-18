from sqlalchemy import Column, BigInteger, Boolean, DateTime, Integer, LargeBinary, SmallInteger, String, Text, MetaData
from sqlalchemy.orm import declarative_base
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.types import TypeDecorator


hafd_METADATA = MetaData(schema="hafd")
HIVE_METADATA = MetaData(schema="hive")

# declarative base class
HiveDataBase = declarative_base(metadata=hafd_METADATA)
HiveBase = declarative_base(metadata=HIVE_METADATA)

class HiveOperation(TypeDecorator):
    impl = LargeBinary
    __visit_name__ = "operation"

    cache_ok = True

    def result_processor(self, dialect, coltype):
        def process(value):
            return fr'{value}'
        return process


class Accounts(HiveDataBase):
    __tablename__ = "accounts"

    id = Column(Integer, primary_key=True)
    name = Column(String)
    block_id = Column(BigInteger, nullable=True)  # NULL for accounts from initial dump


class AccountsView(HiveBase):
    __tablename__ = "accounts_view"

    id = Column(Integer, primary_key=True)
    name = Column(String)

class AccountOperations(HiveDataBase):
    __tablename__ = "account_operations"

    account_id = Column(Integer, primary_key=True)
    transacting_account_id = Column(Integer, primary_key=True)
    account_op_seq_no = Column(Integer, primary_key=True)
    block_id = Column(BigInteger, primary_key=True)
    seq_in_block = Column(Integer)


class Blocks(HiveDataBase):
    __tablename__ = "blocks"

    block_id = Column(BigInteger, primary_key=True)
    hash = Column(LargeBinary)
    prev = Column(LargeBinary)
    created_at = Column(DateTime)
    producer_account_id = Column(Integer)
    transaction_merkle_root = Column(LargeBinary)
    extensions = Column(JSONB)
    witness_signature = Column(LargeBinary)
    signing_key = Column(Text)


class BlocksView(HiveBase):
    __tablename__ = "blocks_view"

    num = Column(Integer, primary_key=True)
    hash = Column(LargeBinary)
    prev = Column(LargeBinary)
    created_at = Column(DateTime)
    producer_account_id = Column(Integer)
    transaction_merkle_root = Column(LargeBinary)
    extensions = Column(JSONB)
    witness_signature = Column(LargeBinary)
    signing_key = Column(Text)


class Operations(HiveDataBase):
    __tablename__ = "operations"

    block_id = Column(BigInteger, primary_key=True)
    seq_in_block = Column(Integer, primary_key=True)
    op_type_id = Column(Integer, primary_key=True)
    trx_in_block = Column(SmallInteger)
    op_pos = Column(Integer)
    body_binary = Column(HiveOperation)
    id = Column(BigInteger)


class OperationsExtendedView(HiveBase):
    __tablename__ = "operations_view_extended"

    id = Column(BigInteger, primary_key=True)
    block_num = Column(Integer)
    trx_in_block = Column(SmallInteger)
    op_pos = Column(Integer)
    op_type_id = Column(SmallInteger)
    timestamp = Column(DateTime)
    body_binary = Column(HiveOperation)

class OperationsView(HiveBase):
    __tablename__ = "operations_view"

    id = Column(BigInteger, primary_key=True)
    block_num = Column(Integer)
    trx_in_block = Column(SmallInteger)
    op_pos = Column(Integer)
    op_type_id = Column(SmallInteger)
    body_binary = Column(HiveOperation)

class OperationsIrreversibleViewExtended(HiveBase):
    __tablename__ = "irreversible_operations_view_extended"

    id = Column(BigInteger, primary_key=True)
    block_num = Column(Integer)
    trx_in_block = Column(SmallInteger)
    op_pos = Column(Integer)
    op_type_id = Column(SmallInteger)
    timestamp = Column(DateTime)
    body_binary = Column(HiveOperation)

class OperationsIrreversibleView(HiveBase):
    __tablename__ = "irreversible_operations_view"

    id = Column(BigInteger, primary_key=True)
    block_num = Column(Integer)
    trx_in_block = Column(SmallInteger)
    op_pos = Column(Integer)
    op_type_id = Column(SmallInteger)
    body_binary = Column(HiveOperation)

class Transactions(HiveDataBase):
    __tablename__ = "transactions"

    block_id = Column(BigInteger, primary_key=True)
    trx_in_block = Column(SmallInteger, primary_key=True)
    trx_hash = Column(LargeBinary, primary_key=True)
    ref_block_num = Column(Integer)
    ref_block_prefix = Column(BigInteger)
    expiration = Column(DateTime)
    signature = Column(LargeBinary)


class TransactionsView(HiveBase):
    __tablename__ = "transactions_view"

    block_num = Column(Integer, primary_key=True)
    trx_in_block = Column(SmallInteger, primary_key=True)
    trx_hash = Column(LargeBinary)
    ref_block_num = Column(Integer)
    ref_block_prefix = Column(BigInteger)
    expiration = Column(DateTime)
    signature = Column(LargeBinary)


class TransactionsMultisig(HiveDataBase):
    __tablename__ = "transactions_multisig"

    trx_hash = Column(LargeBinary, primary_key=True)
    signature = Column(LargeBinary, primary_key=True)
    block_id = Column(BigInteger, primary_key=True)


class EventsQueue(HiveDataBase):
    __tablename__ = "events_queue"

    id = Column(BigInteger, primary_key=True)
    event = Column(String)
    block_num = Column(BigInteger)


class IrreversibleData(HiveDataBase):
    __tablename__ = "hive_state"

    id = Column(Integer, primary_key=True)
    consistent_block = Column(BigInteger)  # block_id encoding block_num and fork_id
    is_dirty = Column(Boolean)
