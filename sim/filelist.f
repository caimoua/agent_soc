+incdir+./testcases
+incdir+../rtl/include

# This template keeps RTL filelists in one place. sim/Makefile rewrites the
# ../filelist/cpu_filelist prefix into FILELIST_DIR when generating
# log/filelist.generated.f.

-f ../filelist/cpu_filelist/common_rtl.f
-f ../filelist/cpu_filelist/core_rtl.f
-f ../filelist/cpu_filelist/mem_rtl.f
-f ../filelist/cpu_filelist/bus_rtl.f
-f ../filelist/cpu_filelist/periph_rtl.f
-f ../filelist/cpu_filelist/top_rtl.f
