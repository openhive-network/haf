#pragma once

#include <string>

namespace pxx_new_types
{

struct timestamp_wo_tz_type
{
    std::string val;
};

inline bool operator != (const timestamp_wo_tz_type& a, const timestamp_wo_tz_type& b)
{
    return a.val != b.val;
}

inline std::ostream& operator<<(std::ostream& os, const timestamp_wo_tz_type& timestamp)
{
    return os << timestamp.val;
}

struct jsonb_string
{
    std::string val;
};

inline bool operator != (const jsonb_string& a, const jsonb_string& b)
{
    return a.val != b.val;
}

inline std::ostream& operator<<(std::ostream& os, const jsonb_string& timestamp)
{
    return os << timestamp.val;
}

} // namespace pxx_new_types
