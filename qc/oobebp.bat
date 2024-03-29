@echo off
echo Bypassing OOBE...
Reagentc /enable
Reagentc /Info /Target C:\Windows
echo Wait until boot status is "Getting Ready"
pause >nul
cls
echo Creating a new user wizard.
set /p username="Username? "
echo You may leave password empty for none
set /p password="Password? "
net user /add %username% %password%
net localgroup users /add %username%
net localgroup administrators /add %username%
cls
echo Finishing up...
reg add HKLM\SYSTEM\Setup /v OOBEInProgress /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\Setup /v SetupType /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\Setup /v SystemSetupInProgress /t REG_DWORD /d 0 /f
echo Done! Press any key to boot into windows!
pause >nul
exit