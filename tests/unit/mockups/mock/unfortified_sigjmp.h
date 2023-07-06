#pragma once

#pragma push_macro( "FORTIFY_SOURCE" )
#undef _FORTIFY_SOURCE
#include <setjmp.h>
#pragma pop_macro( "FORTIFY_SOURCE" )