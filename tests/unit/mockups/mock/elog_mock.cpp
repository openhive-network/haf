extern "C" {
// at the moment not used for test
void elog_start([[maybe_unused]] const char *filename, [[maybe_unused]]  int lineno, [[maybe_unused]] const char *funcname)
{
}

void elog_finish([[maybe_unused]] int elevel, [[maybe_unused]] const char *fmt,...)
{
}

} // extern "C"
