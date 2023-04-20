from __future__ import annotations

from datetime import timedelta
import math
from typing import cast, Optional, TYPE_CHECKING, Union

from haf_local_tools.haf_node._haf_node import HafNode
from test_tools.__private.user_handles.get_implementation import get_implementation
from test_tools.__private.user_handles.handles.node_handles.node_handle_base import NodeHandleBase

if TYPE_CHECKING:
    from sqlalchemy.engine.row import Row
    from sqlalchemy.orm import Session

    from haf_local_tools.db_adapter.db_adapter import ColumnType, ScalarType
    from haf_local_tools.haf_node._haf_node import Transaction, TransactionId
    from test_tools.__private.user_handles.handles.network_handle import NetworkHandle as Network


class HafNodeHandle(NodeHandleBase):
    def __init__(
        self,
        network: Optional[Network] = None,
        database_url: str = HafNode.DEFAULT_DATABASE_URL,
        keep_database: bool = False,
    ) -> None:
        super().__init__(
            implementation=HafNode(
                network=get_implementation(network),
                database_url=database_url,
                keep_database=keep_database,
                handle=self,
            )
        )

    @property
    def __implementation(self) -> HafNode:
        return cast(HafNode, get_implementation(self))

    @property
    def session(self) -> Session:
        """Returns Sqlalchemy database session"""
        return self.__implementation.session

    @property
    def database_url(self) -> str:
        """Returns haf database url"""
        return self.__implementation.database_url

    def wait_for_transaction_in_database(
        self, transaction: Union[Transaction, TransactionId], *, timeout: float | timedelta = math.inf, poll_time: float = 1.0
    ):
        """Function that blocks program execution until a transaction appears in the database

        :param transaction: A transaction that we're waiting for
        :param timeout: Timeout in seconds or preferably timedelta (e.g. tt.Time.minutes(1)).
        :param poll_time: Time between predicate calls.
        """
        return self.__implementation.wait_for_transaction_in_database(transaction, timeout=timeout, poll_time=poll_time)

    def query_all(self, sql: str, **kwargs) -> list[Row]:
        """Execute a SQL query and return all results. (`SELECT n*m`)

        :param sql: The SQL query to execute.
        :param kwargs: Additional parameters to pass to the query.

        :return: A list of `Row` objects representing the result set.
        """
        return self.__implementation.query_all(sql, **kwargs)

    def query_col(self, sql: str, **kwargs) -> ColumnType:
        """Execute a SQL query and return a single column of results. (`SELECT n*1`)

        :param sql: The SQL query to execute.
        :param kwargs: Additional parameters to pass to the query.

        :return: A list of values representing a single column of the result set.
        """
        return self.__implementation.query_col(sql, **kwargs)

    def query_no_return(self, sql: str, **kwargs) -> None:
        """Execute a SQL query and do not return any results.

        :param sql: The SQL query to execute.
        :param kwargs: Additional parameters to pass to the query.
        """
        self.__implementation.query_no_return(sql, **kwargs)

    def query_row(self, sql: str, **kwargs) -> Row:
        """Execute a SQL query and return a single row of results. (`SELECT 1*m`)

        :param sql: The SQL query to execute.
        :param kwargs: Additional parameters to pass to the query.

        :return: A `Row` object representing a single row of the result set.
        """
        return self.__implementation.query_row(sql, **kwargs)

    def query_one(self, sql: str, **kwargs) -> ScalarType:
        """Execute a SQL query and return a single value. (`SELECT 1*1`)

        :param sql: The SQL query to execute.
        :param kwargs: Additional parameters to pass to the query.

        :return: A single value representing the result of the query.
        """
        return self.__implementation.query_one(sql, **kwargs)
