// The few GNU C++ runtime pieces that GNU libstdc++ (libgnustdcxx.a) needs but iOS's libc++abi lacks.
//
// libgnustdcxx.a deliberately leaves out GNU's libsupc++ so that exceptions, RTTI and new/delete come
// from iOS's libc++abi alone. Two GNU-only things remain:
//   - ios_base::failure is thrown through GNU-internal typeinfo classes (cxx11-ios_failure.o, left
//     out of the archive). Streams throw only when a program sets exceptions(); Unity never does, so
//     the throw helpers abort loudly instead.
//   - stream code catches __cxxabiv1::__forced_unwind (thread cancellation unwinding). libc++abi
//     never throws that type, so it only needs a typeinfo, and those handlers never run.
#include <cstdio>
#include <cstdlib>

namespace std {
[[noreturn]] void __throw_ios_failure(const char* msg)
{
    std::fprintf(stderr, "[yoda] GNU libstdc++: ios_base::failure: %s\n", msg ? msg : "");
    std::abort();
}
[[noreturn]] void __throw_ios_failure(const char* msg, int err)
{
    std::fprintf(stderr, "[yoda] GNU libstdc++: ios_base::failure: %s (errno %d)\n", msg ? msg : "", err);
    std::abort();
}
}  // namespace std

namespace __cxxabiv1 {
class __forced_unwind
{
public:
    virtual ~__forced_unwind() throw();
    virtual void __pure_dummy() = 0;
};
__forced_unwind::~__forced_unwind() throw() {}  // key function: emits the typeinfo here
}  // namespace __cxxabiv1
