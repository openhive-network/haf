from sqlalchemy import Column, BigInteger, Boolean, DateTime, Integer, LargeBinary, SmallInteger, String, Text, MetaData
from sqlalchemy.orm import declarative_base
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.types import TypeDecorator


HIVE_METADATA = MetaData(schema="hive")

# declarative base class
Base = declarative_base(metadata=HIVE_METADATA)

class HiveOperation(TypeDecorator):
    impl = LargeBinary
    __visit_name__ = "operation"

    def result_processor(self, dialect, coltype):
        def process(value):
            return fr'{value}'
        return process


class Accounts(Base):
    __tablename__ = "accounts"

    id = Column(Integer, primary_key=True)
    name = Column(String)
    block_num = Column(Integer)


class AccountsReversible(Base):
    __tablename__ = "accounts_reversible"

    id = Column(Integer, primary_key=True)
    name = Column(String)
    block_num = Column(Integer)
    fork_id = Column(Integer, primary_key=True)


class AccountOperations(Base):
    __tablename__ = "account_operations"

    account_id = Column(Integer, primary_key=True)
    account_op_seq_no = Column(Integer, primary_key=True)
    operation_id = Column(BigInteger)


class AccountOperationsReversible(Base):
    __tablename__ = "account_operations_reversible"

    account_id = Column(Integer, primary_key=True)
    account_op_seq_no = Column(Integer, primary_key=True)
    operation_id = Column(BigInteger)
    fork_id = Column(Integer, primary_key=True)


class Blocks(Base):
    __tablename__ = "blocks"

    num = Column(Integer, primary_key=True)
    hash = Column(LargeBinary)
    prev = Column(LargeBinary)
    created_at = Column(DateTime)
    producer_account_id = Column(Integer)
    transaction_merkle_root = Column(LargeBinary)
    extensions = Column(JSONB)
    witness_signature = Column(LargeBinary)
    signing_key = Column(Text)


class BlocksReversible(Base):
    __tablename__ = "blocks_reversible"

    num = Column(Integer, primary_key=True)
    hash = Column(LargeBinary)
    prev = Column(LargeBinary)
    created_at = Column(DateTime)
    producer_account_id = Column(Integer)
    transaction_merkle_root = Column(LargeBinary)
    extensions = Column(JSONB)
    witness_signature = Column(LargeBinary)
    signing_key = Column(Text)
    fork_id = Column(BigInteger, primary_key=True)


class BlocksView(Base):
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


class Operations(Base):
    __tablename__ = "operations"

    id = Column(BigInteger, primary_key=True)
    block_num = Column(Integer)
    trx_in_block = Column(SmallInteger)
    op_pos = Column(Integer)
    op_type_id = Column(SmallInteger)
    timestamp = Column(DateTime)
    body_binary = Column(HiveOperation)


class OperationsReversible(Base):
    __tablename__ = "operations_reversible"

    id = Column(BigInteger, primary_key=True)
    block_num = Column(Integer)
    trx_in_block = Column(SmallInteger)
    op_pos = Column(Integer)
    op_type_id = Column(SmallInteger)
    timestamp = Column(DateTime)
    body_binary = Column(HiveOperation)
    fork_id = Column(BigInteger, primary_key=True)


class Transactions(Base):
    __tablename__ = "transactions"

    block_num = Column(Integer)
    trx_in_block = Column(SmallInteger)
    trx_hash = Column(LargeBinary, primary_key=True)
    ref_block_num = Column(Integer)
    ref_block_prefix = Column(BigInteger)
    expiration = Column(DateTime)
    signature = Column(LargeBinary)


class TransactionsReversible(Base):
    __tablename__ = "transactions_reversible"

    block_num = Column(Integer)
    trx_in_block = Column(SmallInteger)
    trx_hash = Column(LargeBinary, primary_key=True)
    ref_block_num = Column(Integer)
    ref_block_prefix = Column(BigInteger)
    expiration = Column(DateTime)
    signature = Column(LargeBinary)
    fork_id = Column(BigInteger, primary_key=True)


class TransactionsMultisig(Base):
    __tablename__ = "transactions_multisig"

    trx_hash = Column(LargeBinary, primary_key=True)
    signature = Column(LargeBinary, primary_key=True)


class TransactionsMultisigReversible(Base):
    __tablename__ = "transactions_multisig_reversible"

    trx_hash = Column(LargeBinary, primary_key=True)
    signature = Column(LargeBinary, primary_key=True)
    fork_id = Column(BigInteger, primary_key=True)


class EventsQueue(Base):
    __tablename__ = "events_queue"

    id = Column(BigInteger, primary_key=True)
    event = Column(String)
    block_num = Column(BigInteger)


class IrreversibleData(Base):
    __tablename__ = "irreversible_data"

    id = Column(Integer, primary_key=True)
    consistent_block = Column(Integer)
    is_dirty = Column(Boolean)
