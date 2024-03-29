::::::::::::::::::::
:: QC for Windows ::
::   by  zegs32   ::
::::::::::::::::::::
::     Setup      ::
::::::::::::::::::::
set "batch_drive=%~d0"
:: Disable Prompt ::
@echo off
setlocal enabledelayedexpansion

:: Run Main Function ::
goto main

:: Main  Function ::
:main
cls
:: Ask For Bios Type ::
echo Welcome to the Windows QC setup!
echo What is your BIOS type
echo [1] CSM
echo [2] UEFI
choice /c 12 /n /m "BIOS Type? "
:: Run Function that matches Prompt
goto prompt%ERRORLEVEL%
:prompt0
goto main
:prompt1
:: Create a DISKPART script
:: Ask user for what disk to install to
(
    echo list disk
    echo exit
) > script.txt

echo Disks Available:
echo -------------------------------------------------------
set first=1
set disks=
for /f "tokens=1-5" %%a in ('diskpart /s tempScript.txt ^| findstr /R /C:"Disk [0-9]*" /C:"Size [0-9]* GB" /C:"Size [0-9]* B" /C:"Size [0-9]* KB" /C:"Size [0-9]* MB" /C:"Size [0-9]* TB" /C:"Size [0-9]* PB" /C:"Status"') do (
    if defined first (
        set "first="
    ) else (
        set "disks=!disks!%%b"
		echo Disk %%b            ^| Size %%d %%e    ^| Status %%c
    )
)
echo -------------------------------------------------------

choice /c %disks% /n /m "Disk: "
set "curdisk=%ERRORLEVEL%-1"
echo Are you sure^? You will erase everything on this disk^!
choice /c YN /n /m "Y/n? "

if %ERRORLEVEL% EQU 2 goto exitout
if %ERRORLEVEL% EQU 0 goto exitout
:getlabel
set /p label="Windows partition label? "
if "!label!"=="" (
    set "formatted_label=Windows"
) else if "!label:~2!"=="" (
    echo Label must be at least 3 characters long. Please try again.
    goto getlabel
) else (
    :: Truncate the label to 32 characters if it exceeds the limit
    set "formatted_label=!label:~0,32!"
)

(
	echo select disk %curdisk%
	echo clean
	echo convert mbr
	echo create part primary size 500
	echo format quick label Recovery
	echo assign letter R
	echo set id 27
	echo create part primary
	echo format quick label %formatted_label%
	echo assign letter C
	echo active
	echo exit
) > script.txt

diskpart /s script.txt > diskpartlogs.txt

cd %batch_drive%\sources
goto imageSKU
:prompt2
:: Create a DISKPART script
:: Ask user for what disk to install to
(
    echo list disk
    echo exit
) > script.txt

echo Disks Available:
echo -------------------------------------------------------
set first=1
set disks=
for /f "tokens=1-5" %%a in ('diskpart /s script.txt ^| findstr /R /C:"Disk [0-9]*" /C:"Size [0-9]* GB" /C:"Size [0-9]* B" /C:"Size [0-9]* KB" /C:"Size [0-9]* MB" /C:"Size [0-9]* TB" /C:"Size [0-9]* PB" /C:"Status"') do (
    if defined first (
        set "first="
    ) else (
        set "disks=!disks!%%b"
		echo Disk %%b            ^| Size %%d %%e    ^| Status %%c
    )
)
echo -------------------------------------------------------

choice /c %disks% /n /m "Disk: "
set "curdisk=%ERRORLEVEL%-1"
echo Are you sure^? You will erase everything on this disk^!
choice /c YN /n /m "Y/n? "

if %ERRORLEVEL% EQU 2 goto exitout
if %ERRORLEVEL% EQU 0 goto exitout

:getlabel2
set /p label="Windows partition label? "
if "!label!"=="" (
    set "formatted_label=Windows"
) else if "!label:~2!"=="" (
    echo Label must be at least 3 characters long. Please try again.
    goto getlabel2
) else (
    :: Truncate the label to 32 characters if it exceeds the limit
    set "formatted_label=!label:~0,32!"
)

(
	echo select disk %curdisk%
	echo clean
	echo convert gpt
	echo create part efi size 512
	echo create fs fat32 quick
	echo assign letter w
	echo create part msr size 16
	echo create part primary size 500
	echo format quick label Recovery
	echo assign letter R
	echo set id de94bba4-06d1-4d40-a16a-bfd50179d6ac
	echo gpt attributes 0x8000000000000001
	echo create part primary
	echo format quick label %formatted_label%
	echo assign letter C
	echo exit
) > script.txt

diskpart /s script.txt > diskpartlogs.txt

cd %batch_drive%\sources
goto imageSKU
:imageSKU
cls
dism /get-wiminfo /wimfile:%batch_drive%\sources\install.wim > input.txt

@echo off


echo +-------+----------------------------------------------------+
echo ^| Index ^|                        Name                        ^|
echo +-------+----------------------------------------------------+

set index=1
for /f "tokens=1,* delims=:" %%a in ('findstr /R "^Index : [0-9]*$ ^Name : .* ^Size : [0-9\.,]* bytes$" input.txt') do (
    set "line=%%a"
    set "line=!line: =!"
    set "value=%%b"
    if "!line!"=="Index" (
        set "index=%%b"
        if !index! lss 10 (
            set "index= !index!"
        )
    ) else if "!line!"=="Name" (
        set "name=%%b"
        echo ^|  !index!  ^|  !name! 
        set /a "index+=1"
    )
)
echo +-------+---------------------------------------------------+

set /p "skucode=Index? "
if "%skucode%"=="" goto prompt
if %skucode% lss 1 (
    echo Please enter a valid index.
    goto imageSKU
)
if %skucode% gtr %index% (
    echo Please enter a valid index.
    goto imageSKU
)

dism /apply-image /imagefile:%batch_drive%\sources\install.wim /index:%skucode% /applydir:C:

md R:\Recovery\WindowsRE
xcopy /h C:\Windows\System32\Recovery\Winre.wim R:\Recovery\WindowsRE
C:\Windows\System32\Reagentc /Setreimage /Path R:\Recovery\WindowsRE /Target C:\Windows

bcdboot C:\Windows

md C:\Windows\PostInstall
copy %~dp0\oobebp.bat C:\Windows\PostInstall

reg load HKLM\SOFT C:\Windows\System32\config\SOFTWARE
reg load HKLM\SYS C:\Windows\System32\config\SYSTEM
reg add HKLM\SOFT\Microsoft\Windows\CurrentVersion\Policies\System /v VerboseStatus /t REG_DWORD /d 1 /f
reg add HKLM\SOFT\Microsoft\Windows\CurrentVersion\Policies\System /v EnableCursorSuppression /t REG_DWORD /d 0 /f
reg add HKLM\SYS\Setup /v CmdLine /t REG_SZ /d "cmd.exe /c C:\Windows\PostInstall\oobebp.bat" /f

wpeutil reboot
exit
:exitout
cls
echo Aye! Aye!
echo Exitting
exit
