#pragma once

#include <gmock/gmock.h>

#include "include/psql_utils/postgres_includes.hpp"

class IPqMock {
public:
    virtual ~IPqMock() = default;

    virtual PGconn* PQconnectdb(const char*) = 0;
    virtual ConnStatusType PQstatus(const PGconn*) = 0;
    virtual void PQfinish(PGconn*) = 0;
    virtual char* PQerrorMessage(const PGconn*) = 0;
    virtual PGresult *PQexec(PGconn*, const char*) = 0;
    virtual void PQclear(PGresult *res) = 0;
    virtual ExecStatusType PQresultStatus(const PGresult *res) = 0;
    virtual int	PQputCopyEnd(PGconn*, const char*) = 0;
    virtual int	PQputCopyData(PGconn *conn, const char *buffer, int nbytes) = 0;
    virtual char* PQresultErrorMessage(const PGresult *res) = 0;
};

class PqMock : public IPqMock {
public:

    MOCK_METHOD( PGconn*, PQconnectdb, (const char *) );
    MOCK_METHOD( ConnStatusType, PQstatus, (const PGconn *) );
    MOCK_METHOD( void, PQfinish, (PGconn*) );
    MOCK_METHOD( char*, PQerrorMessage, (const PGconn*) ); //"test error" is retuned by default to do not bother with error texts in tests
    MOCK_METHOD( PGresult*, PQexec, (PGconn*, const char*) );
    MOCK_METHOD( void, PQclear, (PGresult*) );
    MOCK_METHOD( ExecStatusType, PQresultStatus, (const PGresult*) );
    MOCK_METHOD( int,	PQputCopyEnd, (PGconn*, const char*) );
    MOCK_METHOD( int, PQputCopyData, (PGconn*, const char*, int) );
    MOCK_METHOD( char*, PQresultErrorMessage, (const PGresult*) );

    static std::shared_ptr<PqMock> create_and_get();
    static std::shared_ptr<PqMock> create_and_get_nice();

private:
    PqMock() = default;
friend class ::testing::NiceMock< PqMock >;
friend class ::testing::StrictMock< PqMock >;
};