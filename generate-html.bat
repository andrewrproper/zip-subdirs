
 
@echo OFF
echo.
echo.
echo == Generating HTML for Markdown (.md) files ==
echo.
echo This requires pandoc for windows to be installed
echo on the system.
echo.
echo =============
echo running pandoc to generate README.html from README.md
echo -------------
pandoc.exe -o README.html README.md
echo =============
echo.
echo.
echo press a key to exit
pause >nul

