from __future__ import annotations

from typing import Any, TYPE_CHECKING, TypeAlias, Union

if TYPE_CHECKING:
    from sqlalchemy.engine.row import Row
    from sqlalchemy.orm.session import Session

    ScalarType: TypeAlias = Any | None
    ColumnType: TypeAlias = list[ScalarType]


class DbAdapter:
    @staticmethod
    def query_all(session: Session, sql: str, **kwargs) -> list[Row]:
        """Perform a `SELECT n*m`"""
        return session.execute(sql, params=kwargs).all()

    @staticmethod
    def query_col(session: Session, sql: str, **kwargs) -> ColumnType:
        """Perform a `SELECT n*1`"""
        return [row[0] for row in session.execute(sql, params=kwargs).all()]

    @staticmethod
    def query_no_return(session: Session, sql: str, **kwargs) -> None:
        """Perform a query with no return"""
        session.execute(sql, params=kwargs).close()

    @staticmethod
    def query_row(session: Session, sql: str, **kwargs) -> Row:
        """Perform a `SELECT 1*m`"""
        return session.execute(sql, params=kwargs).first()

    @staticmethod
    def query_one(session: Session, sql: str, **kwargs) -> ScalarType:
        """Perform a `SELECT 1*1`"""
        return session.execute(sql, params=kwargs).scalar()
