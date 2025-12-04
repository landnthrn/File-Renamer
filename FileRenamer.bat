@echo off
setlocal enabledelayedexpansion

:: Enable ANSI color codes
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "WHITE=%ESC%[0m"
set "GREEN=%ESC%[92m"

:: Temporary file for file list
set "TEMP_FILE=%TEMP%\FileNameChange_%RANDOM%.tmp"

:START
cls
echo %GREEN%==========================
echo        FILE RENAMER
echo ==========================%WHITE%
echo %GREEN%by landn.thrn%WHITE%
echo.

:: ============================================
:: STEP 1: Get Target Folder Path
:: ============================================
:GET_PATH
set "TARGET_PATH="
set /p "TARGET_PATH=Enter the path that contains the files to rename: "

:: Remove quotes if present
set "TARGET_PATH=!TARGET_PATH:"=!"

:: Validate path exists
if not exist "!TARGET_PATH!" (
    echo Error: Path does not exist. Please try again.
    echo.
    goto GET_PATH
)

:: Convert to absolute path and ensure it ends with backslash
for %%F in ("!TARGET_PATH!") do set "TARGET_PATH=%%~fF"
if not "!TARGET_PATH:~-1!"=="\" set "TARGET_PATH=!TARGET_PATH!\"

echo.

:: ============================================
:: STEP 2: Get File Format(s)
:: ============================================
:GET_FORMAT
set "FORMAT_INPUT="
set /p "FORMAT_INPUT=Enter the file format(s) to change: "

:: Remove all spaces
set "FORMAT_INPUT=!FORMAT_INPUT: =!"

:: Check for "all" command
set "IS_ALL=0"
set "EXCLUSIONS="

:: Check if input starts with "all" (case-insensitive)
set "CHECK_ALL=!FORMAT_INPUT!"
if /i "!CHECK_ALL:~0,3!"=="all" (
    set "IS_ALL=1"
    :: Check if there are exclusions (contains "-")
    echo !FORMAT_INPUT! | findstr /i "-" >nul
    if !errorlevel! equ 0 (
        :: Extract exclusions part (everything after the dash)
        for /f "tokens=2* delims=-" %%A in ("!FORMAT_INPUT!") do set "EXCLUSIONS=%%A%%B"
    )
)

:: If not "all", parse formats
set "FORMATS="
if !IS_ALL! equ 0 (
    :: Parse comma-separated formats
    set "TEMP_INPUT=!FORMAT_INPUT!"
    :PARSE_FORMATS
    for /f "tokens=1* delims=," %%A in ("!TEMP_INPUT!") do (
        set "CURRENT_FORMAT=%%A"
        set "TEMP_INPUT=%%B"
        
        :: Remove leading dot if present
        if "!CURRENT_FORMAT:~0,1!"=="." set "CURRENT_FORMAT=!CURRENT_FORMAT:~1!"
        
        :: Add to list (case-insensitive comparison will be done later)
        if defined FORMATS (
            set "FORMATS=!FORMATS! !CURRENT_FORMAT!"
        ) else (
            set "FORMATS=!CURRENT_FORMAT!"
        )
        
        if defined TEMP_INPUT goto PARSE_FORMATS
    )
)

:: Parse exclusions if present
set "EXCLUSION_LIST="
if defined EXCLUSIONS (
    set "TEMP_EXCLUSIONS=!EXCLUSIONS!"
    :PARSE_EXCLUSIONS
    for /f "tokens=1* delims=," %%A in ("!TEMP_EXCLUSIONS!") do (
        set "CURRENT_EXCL=%%A"
        set "TEMP_EXCLUSIONS=%%B"
        
        :: Remove leading dot if present
        if "!CURRENT_EXCL:~0,1!"=="." set "CURRENT_EXCL=!CURRENT_EXCL:~1!"
        
        if defined EXCLUSION_LIST (
            set "EXCLUSION_LIST=!EXCLUSION_LIST! !CURRENT_EXCL!"
        ) else (
            set "EXCLUSION_LIST=!CURRENT_EXCL!"
        )
        
        if defined TEMP_EXCLUSIONS goto PARSE_EXCLUSIONS
    )
)

echo.

:: ============================================
:: STEP 3: Get Subfolder Option
:: ============================================
:GET_SUBFOLDER
echo.
echo How do you want to scan/rename files? In:
echo.
echo 1 - All Subfolders of Target Folder
echo 2 - First Forefront Subfolders of Target Folder
echo 3 - Only Target Folder
echo.
set "SUBFOLDER_OPTION="
set /p "SUBFOLDER_OPTION=Enter Command: "

if not "!SUBFOLDER_OPTION!"=="1" if not "!SUBFOLDER_OPTION!"=="2" if not "!SUBFOLDER_OPTION!"=="3" (
    echo Invalid option. Please enter 1, 2, or 3.
    echo.
    goto GET_SUBFOLDER
)

echo.

:: ============================================
:: STEP 4: Scan and Preview Files
:: ============================================
echo %GREEN%Scanning files...%WHITE%
echo.

:: Clear temp file
> "!TEMP_FILE!" echo.

set "FILE_COUNT=0"

:: Build file list based on subfolder option (collect without displaying)
if "!SUBFOLDER_OPTION!"=="3" (
    :: Option 3: Target folder only
    call :SCAN_FOLDER_COLLECT "!TARGET_PATH!" "!TARGET_PATH!"
) else if "!SUBFOLDER_OPTION!"=="2" (
    :: Option 2: First level subfolders only
    call :SCAN_FOLDER_COLLECT "!TARGET_PATH!" "!TARGET_PATH!"
    for /d %%D in ("!TARGET_PATH!*") do (
        if exist "%%D\" (
            call :SCAN_FOLDER_COLLECT "%%D" "!TARGET_PATH!"
        )
    )
) else (
    :: Option 1: All subfolders (recursive)
    call :SCAN_FOLDER_RECURSIVE_COLLECT "!TARGET_PATH!" "!TARGET_PATH!"
)

:: Check if any files found
if !FILE_COUNT! equ 0 (
    echo No files found matching the criteria.
    echo.
    del "!TEMP_FILE!" 2>nul
    pause
    goto START
)

:: Display initial preview
echo.
echo %GREEN%Preview of found files:%WHITE%
for /f "usebackq tokens=1* delims=|" %%A in ("!TEMP_FILE!") do (
    set "RELATIVE_PATH=%%B"
    echo %GREEN%!RELATIVE_PATH!%WHITE%
)

echo.
echo %GREEN%Found !FILE_COUNT! Files%WHITE%
echo.

:: ============================================
:: STEP 5: Get Naming Configuration
:: ============================================
:GET_PREFIX
set "NAME_PREFIX="
echo What would you like the name prefix to be?
echo Example: frame, image, video, shot, ...etc...
echo.
set /p "NAME_PREFIX=Enter Name Prefix: "

if not defined NAME_PREFIX (
    echo Prefix cannot be empty. Please try again.
    echo.
    goto GET_PREFIX
)

:: Replace spaces with underscores
set "NAME_PREFIX=!NAME_PREFIX: =_!"

echo.

:GET_START_NUMBER
set "START_NUMBER="
set /p "START_NUMBER=What number do you want to start at? "

:: Remove all spaces
set "START_NUMBER=!START_NUMBER: =!"

:: Check if empty
if not defined START_NUMBER (
    echo Invalid number. Please enter a valid number.
    echo.
    goto GET_START_NUMBER
)

:: Validate number using a helper function
call :VALIDATE_NUMBER "!START_NUMBER!"
if errorlevel 1 (
    echo Invalid number. Please enter a valid number.
    echo.
    goto GET_START_NUMBER
)

echo.

:: ============================================
:: STEP 5B: Get Number Placement
:: ============================================
:GET_NUMBER_PLACEMENT
echo Do you want the numbers placed on left or right side of names?
echo.
echo Example: 1_frame or frame_1
echo.
echo L - Left (number_suffix)
echo R - Right (prefix_number)
echo.
set "NUMBER_PLACEMENT="
set /p "NUMBER_PLACEMENT=Enter Command: "

if /i not "!NUMBER_PLACEMENT!"=="L" if /i not "!NUMBER_PLACEMENT!"=="R" (
    echo Invalid option. Please enter L or R.
    echo.
    goto GET_NUMBER_PLACEMENT
)

echo.

:: ============================================
:: STEP 6: Confirmation
:: ============================================
:CONFIRM
echo Ready to rename the files?
echo.
echo Y - Yes
echo N - No
echo.
set "CONFIRM_ACTION="
set /p "CONFIRM_ACTION=Enter Command: "

if /i "!CONFIRM_ACTION!"=="N" (
    echo.
    del "!TEMP_FILE!" 2>nul
    goto START
)

if /i not "!CONFIRM_ACTION!"=="Y" (
    echo Invalid option. Please enter Y or N.
    echo.
    goto CONFIRM
)

:: ============================================
:: STEP 7: Perform Renaming
:: ============================================
echo.
echo %GREEN%Renaming files...%WHITE%
echo.

set "RENAME_COUNT=0"
set "CURRENT_NUMBER=!START_NUMBER!"

:: Process each file from temp file
for /f "usebackq tokens=1* delims=|" %%A in ("!TEMP_FILE!") do (
    set "FILE_PATH=%%A"
    set "RELATIVE_PATH=%%B"
    
    :: Get file extension
    for %%F in ("!FILE_PATH!") do (
        set "FILE_EXT=%%~xF"
        set "FILE_DIR=%%~dpF"
    )
    
    :: Remove leading dot from extension
    if "!FILE_EXT:~0,1!"=="." set "FILE_EXT=!FILE_EXT:~1!"
    
    :: Build new name based on number placement
    if /i "!NUMBER_PLACEMENT!"=="L" (
        :: Left placement: number_suffix.ext
        set "NEW_NAME=!CURRENT_NUMBER!_!NAME_PREFIX!.!FILE_EXT!"
    ) else (
        :: Right placement: prefix_number.ext
        set "NEW_NAME=!NAME_PREFIX!_!CURRENT_NUMBER!.!FILE_EXT!"
    )
    set "NEW_PATH=!FILE_DIR!!NEW_NAME!"
    
    :: Rename file
    if not "!NEW_PATH!"=="!FILE_PATH!" (
        ren "!FILE_PATH!" "!NEW_NAME!" 2>nul
        if !errorlevel! equ 0 (
            echo %GREEN%Renamed: !RELATIVE_PATH! -^> !NEW_NAME!%WHITE%
            set /a RENAME_COUNT+=1
        ) else (
            echo Error renaming: !RELATIVE_PATH!
        )
    )
    
    set /a CURRENT_NUMBER+=1
)

echo.
echo %GREEN%Successfully Renamed !RENAME_COUNT! Files%WHITE%
echo.

:: Clean up temp file
del "!TEMP_FILE!" 2>nul

pause
goto START

:: ============================================
:: FUNCTIONS
:: ============================================

:: Function to validate if input is a number (all digits)
:VALIDATE_NUMBER
set "NUM_TO_CHECK=%~1"
set "IS_NUM=1"

:: Check each character
:VAL_LOOP
if "!NUM_TO_CHECK!"=="" exit /b 0
set "CHAR=!NUM_TO_CHECK:~0,1!"
set "NUM_TO_CHECK=!NUM_TO_CHECK:~1!"

:: Check if character is between 0 and 9
if "!CHAR!" lss "0" exit /b 1
if "!CHAR!" gtr "9" exit /b 1

goto :VAL_LOOP

:: Function to check if format matches (case-insensitive)
:CHECK_FORMAT_MATCH
set "FILE_EXT=%~1"
set "MATCH=0"

:: Remove leading dot
if "!FILE_EXT:~0,1!"=="." set "FILE_EXT=!FILE_EXT:~1!"

:: Check if "all" mode
if !IS_ALL! equ 1 (
    set "MATCH=1"
    :: Check exclusions (case-insensitive)
    if defined EXCLUSION_LIST (
        for %%E in (!EXCLUSION_LIST!) do (
            if /i "!FILE_EXT!"=="%%E" set "MATCH=0"
        )
    )
) else (
    :: Check against format list (case-insensitive)
    if defined FORMATS (
        for %%F in (!FORMATS!) do (
            if /i "!FILE_EXT!"=="%%F" set "MATCH=1"
        )
    )
)

exit /b !MATCH!

:: Function to scan a single folder
:SCAN_FOLDER
set "SCAN_PATH=%~1"
set "BASE_PATH=%~2"

:: Ensure paths end with backslash
if not "!SCAN_PATH:~-1!"=="\" set "SCAN_PATH=!SCAN_PATH!\"
if not "!BASE_PATH:~-1!"=="\" set "BASE_PATH=!BASE_PATH!\"

for %%F in ("!SCAN_PATH!*.*") do (
    :: Skip if it's a directory
    if exist "%%F\" goto :SCAN_SKIP
    
    :: Get extension
    for %%E in ("%%F") do set "FILE_EXT=%%~xE"
    
    :: Check format match
    call :CHECK_FORMAT_MATCH "!FILE_EXT!"
    if !errorlevel! equ 1 (
        :: Get filename
        for %%N in ("%%F") do set "FILE_NAME=%%~nxN"
        
        :: Get target folder name (last part of BASE_PATH)
        set "TARGET_FOLDER_NAME="
        set "BASE_PATH_NO_SLASH=!BASE_PATH:~0,-1!"
        if defined BASE_PATH_NO_SLASH (
            for %%P in ("!BASE_PATH_NO_SLASH!") do set "TARGET_FOLDER_NAME=%%~nxP"
        )
        :: If empty (e.g., drive root), use the path itself
        if not defined TARGET_FOLDER_NAME set "TARGET_FOLDER_NAME=!BASE_PATH_NO_SLASH!"
        
        :: Build relative path for display
        set "REL_PATH=!SCAN_PATH!"
        set "REL_PATH=!REL_PATH:%BASE_PATH%=!"
        
        :: Format relative path
        if "!REL_PATH!"=="" (
            :: File is in target folder - show as \TargetFolder\filename
            set "DISPLAY_PATH=\!TARGET_FOLDER_NAME!\!FILE_NAME!"
        ) else (
            :: File is in subfolder
            if "!REL_PATH:~-1!"=="\" set "REL_PATH=!REL_PATH:~0,-1!"
            :: Remove leading backslash if present
            if "!REL_PATH:~0,1!"=="\" set "REL_PATH=!REL_PATH:~1!"
            set "DISPLAY_PATH=\!TARGET_FOLDER_NAME!\!REL_PATH!\!FILE_NAME!"
        )
        
        :: Write to temp file: full path|display path
        echo %%F^|!DISPLAY_PATH!>> "!TEMP_FILE!"
        
        :: Display in green
        echo %GREEN%!DISPLAY_PATH!%WHITE%
        
        set /a FILE_COUNT+=1
    )
)
:SCAN_SKIP
exit /b

:: Function to scan recursively
:SCAN_FOLDER_RECURSIVE
set "SCAN_PATH=%~1"
set "BASE_PATH=%~2"

:: Ensure paths end with backslash
if not "!SCAN_PATH:~-1!"=="\" set "SCAN_PATH=!SCAN_PATH!\"
if not "!BASE_PATH:~-1!"=="\" set "BASE_PATH=!BASE_PATH!\"

:: Scan current folder
call :SCAN_FOLDER "!SCAN_PATH!" "!BASE_PATH!"

:: Scan subfolders recursively
for /d %%D in ("!SCAN_PATH!*") do (
    if exist "%%D\" (
        call :SCAN_FOLDER_RECURSIVE "%%D" "!BASE_PATH!"
    )
)

exit /b

:: Function to scan a single folder (collection only, no display)
:SCAN_FOLDER_COLLECT
set "SCAN_PATH=%~1"
set "BASE_PATH=%~2"

:: Ensure paths end with backslash
if not "!SCAN_PATH:~-1!"=="\" set "SCAN_PATH=!SCAN_PATH!\"
if not "!BASE_PATH:~-1!"=="\" set "BASE_PATH=!BASE_PATH!\"

for %%F in ("!SCAN_PATH!*.*") do (
    :: Skip if it's a directory
    if exist "%%F\" goto :SCAN_COLLECT_SKIP
    
    :: Get extension
    for %%E in ("%%F") do set "FILE_EXT=%%~xE"
    
    :: Check format match
    call :CHECK_FORMAT_MATCH "!FILE_EXT!"
    if !errorlevel! equ 1 (
        :: Get filename
        for %%N in ("%%F") do set "FILE_NAME=%%~nxN"
        
        :: Get target folder name (last part of BASE_PATH)
        set "TARGET_FOLDER_NAME="
        set "BASE_PATH_NO_SLASH=!BASE_PATH:~0,-1!"
        if defined BASE_PATH_NO_SLASH (
            for %%P in ("!BASE_PATH_NO_SLASH!") do set "TARGET_FOLDER_NAME=%%~nxP"
        )
        :: If empty (e.g., drive root), use the path itself
        if not defined TARGET_FOLDER_NAME set "TARGET_FOLDER_NAME=!BASE_PATH_NO_SLASH!"
        
        :: Build relative path for display
        set "REL_PATH=!SCAN_PATH!"
        set "REL_PATH=!REL_PATH:%BASE_PATH%=!"
        
        :: Format relative path
        if "!REL_PATH!"=="" (
            :: File is in target folder - show as \TargetFolder\filename
            set "DISPLAY_PATH=\!TARGET_FOLDER_NAME!\!FILE_NAME!"
        ) else (
            :: File is in subfolder
            if "!REL_PATH:~-1!"=="\" set "REL_PATH=!REL_PATH:~0,-1!"
            :: Remove leading backslash if present
            if "!REL_PATH:~0,1!"=="\" set "REL_PATH=!REL_PATH:~1!"
            set "DISPLAY_PATH=\!TARGET_FOLDER_NAME!\!REL_PATH!\!FILE_NAME!"
        )
        
        :: Write to temp file: full path|display path
        echo %%F^|!DISPLAY_PATH!>> "!TEMP_FILE!"
        
        set /a FILE_COUNT+=1
    )
)
:SCAN_COLLECT_SKIP
exit /b

:: Function to scan recursively (collection only, no display)
:SCAN_FOLDER_RECURSIVE_COLLECT
set "SCAN_PATH=%~1"
set "BASE_PATH=%~2"

:: Ensure paths end with backslash
if not "!SCAN_PATH:~-1!"=="\" set "SCAN_PATH=!SCAN_PATH!\"
if not "!BASE_PATH:~-1!"=="\" set "BASE_PATH=!BASE_PATH!\"

:: Scan current folder
call :SCAN_FOLDER_COLLECT "!SCAN_PATH!" "!BASE_PATH!"

:: Scan subfolders recursively
for /d %%D in ("!SCAN_PATH!*") do (
    if exist "%%D\" (
        call :SCAN_FOLDER_RECURSIVE_COLLECT "%%D" "!BASE_PATH!"
    )
)

exit /b

