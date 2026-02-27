/**
 * strip_json_null_escapes(TEXT) RETURNS TEXT
 *
 * Strips JSON \u0000 null-byte escape sequences from a JSON text string,
 * respecting backslash escaping so that \\u0000 (an escaped backslash
 * followed by literal "u0000") is preserved.
 *
 * Algorithm: single-pass scan. When we find the 5-char suffix "u0000"
 * preceded by a backslash, we count consecutive backslashes immediately
 * before that position. If the count (including the one before "u0000")
 * is odd, the last backslash starts a \u0000 escape — strip it.
 * If even, all backslashes are paired (\\) and "u0000" is literal text.
 *
 * Examples:
 *   \u0000       → (stripped)        0 preceding \\, odd total(1) → strip
 *   \\u0000      → \\u0000           1 preceding \\, even total(2) → keep
 *   \\\u0000     → \\(stripped)      2 preceding \\, odd total(3) → strip
 *   \\\\u0000    → \\\\u0000         3 preceding \\, even total(4) → keep
 *
 * Returns the input unchanged if no \u0000 sequences are found.
 * Returns NULL on NULL input (declared STRICT).
 */

#include <psql_utils/postgres_includes.hpp>

extern "C"
{

PG_FUNCTION_INFO_V1( strip_json_null_escapes );

Datum strip_json_null_escapes( PG_FUNCTION_ARGS )
{
  text* input  = PG_GETARG_TEXT_PP( 0 );
  int   len    = VARSIZE_ANY_EXHDR( input );
  const char* src = VARDATA_ANY( input );

  /* Fast path: scan for any backslash at all.  Most JSON texts won't
   * contain \u0000, so we can return the input as-is without copying. */
  const char* first_bs = static_cast<const char*>( memchr( src, '\\', len ) );
  if( first_bs == nullptr )
    PG_RETURN_TEXT_P( input );

  /* Allocate output buffer — same size as input (stripping only shrinks). */
  char* dst = static_cast<char*>( palloc( len ) );
  int   out = 0;

  for( int i = 0; i < len; )
  {
    /* Look for a backslash that could start \u0000. */
    if( src[i] == '\\' && i + 5 < len
        && src[i+1] == 'u'
        && src[i+2] == '0'
        && src[i+3] == '0'
        && src[i+4] == '0'
        && src[i+5] == '0' )
    {
      /* Count consecutive backslashes already written ending at out-1.
       * These are the backslashes immediately preceding this \u0000
       * in the original text (since we copy non-matching chars verbatim). */
      int bs_count = 0;
      while( bs_count < out && dst[out - 1 - bs_count] == '\\' )
        ++bs_count;

      if( bs_count % 2 == 0 )
      {
        /* Even preceding backslashes: this \ is unescaped → real \u0000.
         * Skip all 6 characters (\u0000). */
        i += 6;
        continue;
      }
      /* Odd preceding backslashes: this \ is part of a \\ pair.
       * Fall through to copy it normally. */
    }

    dst[out++] = src[i++];
  }

  /* If nothing was stripped, return the original to avoid a copy. */
  if( out == len )
  {
    pfree( dst );
    PG_RETURN_TEXT_P( input );
  }

  text* result = static_cast<text*>( palloc( VARHDRSZ + out ) );
  SET_VARSIZE( result, VARHDRSZ + out );
  memcpy( VARDATA( result ), dst, out );
  pfree( dst );
  PG_RETURN_TEXT_P( result );
}

} /* extern "C" */
