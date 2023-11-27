from __future__ import annotations

from datetime import timedelta
import math
from typing import Final, TYPE_CHECKING, TypedDict, Union
from uuid import uuid4

import sqlalchemy
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import NullPool
from sqlalchemy_utils import create_database, database_exists, drop_database

import test_tools as tt
from test_tools.__private.preconfigured_node import PreconfiguredNode

from haf_local_tools.db_adapter import DbAdapter

if TYPE_CHECKING:
    from sqlalchemy.engine.row import Row

    from test_tools.__private.user_handles.handles.node_handles.node_handle_base import NodeHandleBase as NodeHandle

    from haf_local_tools.db_adapter import ColumnType, ScalarType

class Transaction(TypedDict):
    transaction_id: str

TransactionId = str

class HafNode(PreconfiguredNode):
    DEFAULT_DATABASE_URL: Final[str] = "postgresql:///haf_block_log"

    def __init__(
        self,
        *,
        name: str = "HafNode",
        network: tt.Network | None = None,
        database_url: str = DEFAULT_DATABASE_URL,
        keep_database: bool = False,
        create_unique_database: bool = True,
        handle: NodeHandle | None = None,
    ) -> None:
        super().__init__(name=name, network=network, handle=handle)
        self.__database_url: str = self.__create_unique_url(database_url) if create_unique_database else database_url
        self.__session: Session | None = None
        self.__keep_database: bool = keep_database
        self.create_unique_database: bool = create_unique_database
        self.__is_database_created: bool = False

        self.config.plugin.append("sql_serializer")
        self.config.psql_operations_threads_number = 3

        self.config.log_appender = '{"appender":"stderr","stream":"std_error"}'
        self.config.log_logger = '{"name":"default","level":"info","appender":"stderr"}'

    @property
    def session(self) -> Session:
        assert self.__session, "Session is not available since node was not run yet! Call the 'run()' method first."
        return self.__session

    @property
    def database_url(self) -> str:
        return self.__database_url

    def _actions_before_run(self) -> None:
        self.__make_database()

    @staticmethod
    def __create_unique_url(database_url):
        return database_url + "_" + uuid4().hex

    def __make_database(self) -> None:
        self.config.psql_url = self.__database_url

        if self.create_unique_database and self.__is_database_created is False:
            self.logger.info(f"Preparing database {self.__database_url}")
            if database_exists(self.__database_url):
                drop_database(self.__database_url)
            create_database(self.__database_url, template="haf_block_log")
            self.__is_database_created = True

        engine = sqlalchemy.create_engine(self.__database_url, echo=False, poolclass=NullPool, isolation_level="AUTOCOMMIT")
        session = sessionmaker(bind=engine)
        self.__session = session()

    def close(self) -> None:
        super().close()
        self.__close_session()

    def __close_session(self) -> None:
        if self.__session is not None:
            self.__session.close()

    def _actions_after_final_cleanup(self) -> None:
        if not self.__keep_database:
            drop_database(self.__database_url)

    def wait_for_transaction_in_database(
        self,
        transaction:  Union[Transaction, TransactionId],
        *,
        timeout: float | timedelta = math.inf,
        poll_time: float = 1.0,
    ):
        if isinstance(transaction, dict):
            transaction_hash = transaction["transaction_id"]

        if isinstance(transaction, TransactionId):
            transaction_hash = transaction

        tt.Time.wait_for(
            lambda: self.__is_transaction_in_database(transaction_hash),
            timeout=timeout,
            timeout_error_message=f"Waited too long for transaction {transaction_hash}",
            poll_time=poll_time,
        )

    def __is_transaction_in_database(self, trx_id: str) -> bool:
        sql = "SELECT exists(SELECT 1 FROM hive.transactions_view WHERE trx_hash = decode(:hash, 'hex'));"
        return self.query_one(sql, hash=trx_id)

    def query_all(self, sql: str, **kwargs) -> list[Row]:
        return DbAdapter.query_all(self.session, sql, **kwargs)

    def query_col(self, sql: str, **kwargs) -> ColumnType:
        return DbAdapter.query_col(self.session, sql, **kwargs)

    def query_no_return(self, sql: str, **kwargs) -> None:
        DbAdapter.query_no_return(self.session, sql, **kwargs)

    def query_row(self, sql: str, **kwargs) -> Row:
        return DbAdapter.query_row(self.session, sql, **kwargs)

    def query_one(self, sql: str, **kwargs) -> ScalarType:
        return DbAdapter.query_one(self.session, sql, **kwargs)
