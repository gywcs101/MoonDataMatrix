// Original platform adapter. Encoding remains entirely in MoonBit.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include "moonbit.h"
#ifdef _WIN32
#include <windows.h>
static wchar_t *wide(const char *s) {
 int n=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s,-1,NULL,0);
 if(!n)return NULL;
 wchar_t *p=(wchar_t*)malloc(n*sizeof(wchar_t));
 if(p && !MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s,-1,p,n)){free(p);return NULL;}
 return p;
}
#else
#include <unistd.h>
#ifdef __linux__
#include <sys/syscall.h>
#include <fcntl.h>
#endif
#endif
MOONBIT_FFI_EXPORT int mdm_publish(moonbit_bytes_t a, moonbit_bytes_t b) {
#ifdef _WIN32
 wchar_t *src=wide((char*)a),*dst=wide((char*)b);
 if(!src||!dst){free(src);free(dst);return -1;}
 int result=MoveFileExW(src,dst,0)?0:-1;
 free(src);free(dst);return result;
#elif defined(__linux__)
 return syscall(SYS_renameat2,AT_FDCWD,(char*)a,AT_FDCWD,(char*)b,1);
#elif defined(__APPLE__)
 return renamex_np((char*)a,(char*)b,RENAME_EXCL);
#else
 return -1;
#endif
}
MOONBIT_FFI_EXPORT void mdm_stderr(moonbit_bytes_t bytes) {
 fputs((char*)bytes,stderr);fputc('\n',stderr);
}

#ifdef _WIN32
MOONBIT_FFI_EXPORT moonbit_string_t *mdm_windows_args(void) {
 typedef LPWSTR *(WINAPI *ParseCommandLine)(LPCWSTR,int*);
 HMODULE module=LoadLibraryW(L"shell32.dll");
 if(!module){fputs("cannot load Windows argument parser\n",stderr);exit(4);}
 ParseCommandLine parse=(ParseCommandLine)GetProcAddress(module,"CommandLineToArgvW");
 int count=0;LPWSTR *argv=parse?parse(GetCommandLineW(),&count):NULL;
 if(!argv){FreeLibrary(module);fputs("cannot parse Windows arguments\n",stderr);exit(4);}
 moonbit_string_t *result=(moonbit_string_t*)moonbit_make_ref_array_raw(count);
 for(int i=0;i<count;i++){
  int len=(int)wcslen(argv[i]);result[i]=moonbit_make_string_raw(len);
  memcpy(result[i],argv[i],len*sizeof(wchar_t));
 }
 LocalFree(argv);FreeLibrary(module);return result;
}
#endif
