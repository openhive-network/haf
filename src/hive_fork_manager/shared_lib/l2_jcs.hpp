#pragma once

#include <string>

namespace fc { class variant; }

namespace l2
{
  /**
   * Append the RFC-8785 (JSON Canonicalization Scheme) serialization of `v` to `out`.
   *
   * This is the canonical form used to build a second-layer transaction's signing
   * digest: sha256( chain_id || jcs( {app, version, operations, expiration, nonce?} ) ).
   *
   * Restricted numeric profile (so wallets in any language stay bit-compatible and
   * signatures bind exact values): only integers within +-(2^53 - 1) are allowed.
   * Floating-point numbers and out-of-range integers are rejected (FC_ASSERT, which
   * the caller surfaces as a PostgreSQL error) — carry such values as strings.
   *
   * Object keys are ordered by UTF-16 code unit (per RFC-8785). Strings are
   * minimally escaped; all other characters are emitted as raw UTF-8.
   */
  void jcs_canonicalize( const fc::variant& v, std::string& out );
}
