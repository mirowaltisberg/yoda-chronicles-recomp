// Functions the 2015 engine library calls with GNU libstdc++ types or that no shipped library defines.
//
// The engine was compiled against Apple's GCC 4.2 libstdc++; this app is compiled against libc++.
// Where a Trampoline function takes a std::string, the engine expects the GNU mangling (std::string =
// "Ss") and the GNU copy-on-write layout, so the bridge receives the GNU string as an opaque pointer and
// fills it through GNU libstdc++'s own std::string::assign (from libgnustdcxx.a).
#include <string>
#include <cstring>
#include <cstdio>

void UnityKeyboard_GetText(std::string* text);  // Trampoline's Keyboard.mm, compiled against libc++

extern "C" void* GnuStringAssign(void* self, const char* s, unsigned long n) __asm__("__ZNSs6assignEPKcm");
extern "C" void GnuUnityKeyboardGetText(void* gnuString) __asm__("__Z21UnityKeyboard_GetTextPSs");

void GnuUnityKeyboardGetText(void* gnuString)
{
    std::string text;
    UnityKeyboard_GetText(&text);
    GnuStringAssign(gnuString, text.data(), text.size());
}

// Referenced by the engine library but defined in none of the libraries Unity 4.6.6 ships for iOS
// (LZMA-compressed web streams / asset bundles). The game loads neither, so the decoder reports failure.
namespace Alg { namespace Compression { namespace Lzma {
enum CompressPrefix {};
int decode(CompressPrefix, void*, unsigned long, const unsigned char*, const char*, unsigned long)
{
    std::fprintf(stderr, "[yoda] Alg::Compression::Lzma::decode called; not available in this build\n");
    return 0;
}
}}}
