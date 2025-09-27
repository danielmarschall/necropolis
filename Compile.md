
# How to compile

# Necropolis.exe

1. Open Necropolis.dbpro with DarkBASIC Professional and build the executable. Make sure the build mode is "alone" (otherwise signing the EXE is not possible)

2. Edit Necropolis.exe with Resource Hacker (only cosmetics):

- Fix icon by replacing icon resource 105 (Reason: DBPro fails with replacing the icon due to a bug)

- Fix version info (Reasons: Comments and Copyright might be cut off; Internal Name is filled with Version for some reason; Original Filename contains the full path instead of just the file name; Version Number is always reset to v1.0; Machine readable version number is not changed)

3. Sign the EXE using Authenticode

You can keep Necropolis.exe for future builds (unless you change the DBPro version), since only the .pck file changes.
