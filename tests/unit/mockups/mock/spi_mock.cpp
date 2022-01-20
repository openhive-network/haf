#include "spi_mock.hpp"

#include <cassert>
#include <memory>

SPITupleTable *SPI_tuptable;
uint64 SPI_processed;

namespace {
  // NOLINTNEXTLINE(fuchsia-statically-constructed-objects)
    std::weak_ptr< SpiMock > SPI_MOCK;
} // namespace

std::shared_ptr<SpiMock> SpiMock::create_and_get() {
  assert( SPI_MOCK.lock() == nullptr && "Use only one mock instance" );
  auto instance = std::make_shared< SpiMock >();
  SPI_MOCK = instance;
  return instance;
}

extern "C" {
int SPI_connect() {
  assert(SPI_MOCK.lock() && "No mock cretaed, plese execute first SpiMock::create_and_get");

  return SPI_MOCK.lock()->SPI_connect();
}

int SPI_finish() {
  assert(SPI_MOCK.lock() && "No mock cretaed, plese execute first SpiMock::create_and_get");

  return SPI_MOCK.lock()->SPI_finish();
}

Datum SPI_getbinval(HeapTuple _tuple, TupleDesc _desc, int _field, bool* _is_null) {
  assert(SPI_MOCK.lock() && "No mock cretaed, plese execute first SpiMock::create_and_get");
  return SPI_MOCK.lock()->SPI_getbinval( _tuple, _desc, _field, _is_null);
}

char* SPI_gettype(TupleDesc tupdesc, int fnumber) {
  assert(SPI_MOCK.lock() && "No mock cretaed, plese execute first SpiMock::create_and_get");
  return SPI_MOCK.lock()->SPI_gettype( tupdesc, fnumber );
}

int	SPI_execute(const char *src, bool read_only, long tcount) {
  assert(SPI_MOCK.lock() && "No mock cretaed, plese execute first SpiMock::create_and_get");
  return SPI_MOCK.lock()->SPI_execute( src, read_only, tcount );
}

void SPI_freetuptable(SPITupleTable *tuptable) {
  assert(SPI_MOCK.lock() && "No mock cretaed, plese execute first SpiMock::create_and_get");
  return SPI_MOCK.lock()->SPI_freetuptable( tuptable );
}

} // extern "C"
