extern "C" {
// at the moment not used for test
void elog_start([[maybe_unused]] const char *filename, [[maybe_unused]]  int lineno, [[maybe_unused]] const char *funcname)
{
}

void elog_finish([[maybe_unused]] int elevel, [[maybe_unused]] const char *fmt,...)
{
}

bool errstart([[maybe_unused]] int elevel, [[maybe_unused]] const char *domain) {
  return true;
}

void errfinish([[maybe_unused]] const char *filename, [[maybe_unused]] int lineno, [[maybe_unused]] const char *funcname) {
}

int	errmsg_internal([[maybe_unused]] const char *fmt,...) {
  return 0;
}

bool errstart_cold([[maybe_unused]] int elevel, [[maybe_unused]] const char *domain){
  return true;
}

} // extern "C"
