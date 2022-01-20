#include "pq_mock.hpp"

#include <cassert>
#include <memory>

namespace {
  // NOLINTNEXTLINE(fuchsia-statically-constructed-objects)
  std::weak_ptr< PqMock > PQ_MOCK;
} // namespace

std::shared_ptr<PqMock> PqMock::create_and_get() {
  assert( PQ_MOCK.lock() == nullptr && "Use only one mock instance" );
  auto instance = std::shared_ptr< PqMock >( new ::testing::StrictMock<PqMock>() );
  PQ_MOCK = instance;
  return instance;
}

std::shared_ptr<PqMock> PqMock::create_and_get_nice() {
  assert( PQ_MOCK.lock() == nullptr && "Use only one mock instance" );
  auto instance = std::shared_ptr< PqMock >( new ::testing::NiceMock<PqMock>() );
  PQ_MOCK = instance;
  return instance;
}

extern "C" {
PGconn* PQconnectdb( const char* _conninfo ) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQconnectdb( _conninfo );
}

ConnStatusType PQstatus( const PGconn* _connection ) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQstatus( _connection );
}

void PQfinish(PGconn* _connection ) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQfinish( _connection );
}

char* PQerrorMessage(const PGconn* _connection) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  ::testing::DefaultValue<char*>::Set( const_cast< char* >( "test error" ) );
  auto *res = PQ_MOCK.lock()->PQerrorMessage( _connection );
  return res;
}

PGresult* PQexec(PGconn* _connection, const char* _query) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQexec( _connection, _query );
}

void PQclear(PGresult* _res) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQclear( _res );
}

ExecStatusType PQresultStatus(const PGresult* _res) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQresultStatus( _res );
}

int	PQputCopyEnd(PGconn* _connection, const char* _errormsg) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQputCopyEnd( _connection, _errormsg );
}

int	PQputCopyData(PGconn* _conn, const char* _buffer, int _nbytes) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQputCopyData( _conn, _buffer, _nbytes );
}

char* PQresultErrorMessage(const PGresult *res) {
  assert(PQ_MOCK.lock() && "No mock created, plese execute first PqMock::create_and_get");
  return PQ_MOCK.lock()->PQresultErrorMessage( res );
}

} // extern "C"

