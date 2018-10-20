@ECHO OFF
C:\DOS\SMARTDRV.EXE /X
PROMPT $p$g
PATH C:\DOS;C:\TOOLS;C:\WINDOWS;
set TEMP=C:\DOS\TEMP
MODE CON RATE=32 DELAY=1
loadhigh KEYB SP
loadhigh DOSKEY /INSERT
loadhigh ctmouse
date 12-5-2018
c:\emu87\88x87.com
