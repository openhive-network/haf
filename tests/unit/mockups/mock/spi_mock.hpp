#pragma once

#include <gmock/gmock.h>

#include "psql_utils/postgres_includes.hpp"

class ISpiMock {
public:
    virtual ~ISpiMock() = default;

    virtual int SPI_connect() = 0;
    virtual int SPI_finish() = 0;
    virtual Datum SPI_getbinval(HeapTuple, TupleDesc, int, bool*) = 0;
    virtual char* SPI_gettype(TupleDesc tupdesc, int fnumber) = 0;
    virtual int	SPI_execute(const char *src, bool read_only, long tcount) = 0;
    virtual void SPI_freetuptable(SPITupleTable *tuptable) = 0;
};

class SpiMock : public ISpiMock {
public:
    MOCK_METHOD( int, SPI_connect, () );
    MOCK_METHOD( int, SPI_finish, () );
    MOCK_METHOD( Datum, SPI_getbinval, (HeapTuple, TupleDesc, int, bool*) );
    MOCK_METHOD( char*, SPI_gettype, (TupleDesc, int) );
    MOCK_METHOD( int, SPI_execute, (const char*, bool, long) );
    MOCK_METHOD( void, SPI_freetuptable, (SPITupleTable*) );

    static std::shared_ptr<SpiMock> create_and_get();
};
