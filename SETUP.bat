@echo off
echo ============================================
echo  LuckyRupee Flutter Project Setup
echo ============================================
echo.

SET PROJECT=C:\Users\admin\Desktop\luckyrupee

echo [1/5] Creating folder structure...
mkdir "%PROJECT%\lib\screens\auth" 2>nul
mkdir "%PROJECT%\lib\screens\home" 2>nul
mkdir "%PROJECT%\lib\screens\draw" 2>nul
mkdir "%PROJECT%\lib\screens\wallet" 2>nul
mkdir "%PROJECT%\lib\screens\referral" 2>nul
mkdir "%PROJECT%\lib\screens\profile" 2>nul
mkdir "%PROJECT%\lib\providers" 2>nul
mkdir "%PROJECT%\lib\widgets" 2>nul
mkdir "%PROJECT%\lib\services" 2>nul
mkdir "%PROJECT%\lib\models" 2>nul
echo    Done.

echo.
echo [2/5] Copying source files...

SET SRC=%~dp0flutter\lib

copy /Y "%SRC%\main.dart"                                          "%PROJECT%\lib\main.dart"
copy /Y "%SRC%\screens\auth\splash_screen.dart"                    "%PROJECT%\lib\screens\auth\splash_screen.dart"
copy /Y "%SRC%\screens\auth\auth_screens.dart"                     "%PROJECT%\lib\screens\auth\auth_screens.dart"
copy /Y "%SRC%\screens\home\home_screen.dart"                      "%PROJECT%\lib\screens\home\home_screen.dart"
copy /Y "%SRC%\screens\draw\draw_detail_screen.dart"               "%PROJECT%\lib\screens\draw\draw_detail_screen.dart"
copy /Y "%SRC%\screens\wallet\wallet_screen.dart"                   "%PROJECT%\lib\screens\wallet\wallet_screen.dart"
copy /Y "%SRC%\screens\wallet\jazzcash_screen.dart"                "%PROJECT%\lib\screens\wallet\jazzcash_screen.dart"
copy /Y "%SRC%\screens\referral\referral_and_profile.dart"         "%PROJECT%\lib\screens\referral\referral_and_profile.dart"
copy /Y "%SRC%\screens\referral\referral_screen.dart"              "%PROJECT%\lib\screens\referral\referral_screen.dart"
copy /Y "%SRC%\screens\profile\profile_screen.dart"                "%PROJECT%\lib\screens\profile\profile_screen.dart"
copy /Y "%SRC%\providers\all_providers.dart"                       "%PROJECT%\lib\providers\all_providers.dart"
copy /Y "%SRC%\providers\auth_notifier.dart"                       "%PROJECT%\lib\providers\auth_notifier.dart"
copy /Y "%SRC%\widgets\shared_widgets.dart"                        "%PROJECT%\lib\widgets\shared_widgets.dart"
copy /Y "%SRC%\services\api_service.dart"                          "%PROJECT%\lib\services\api_service.dart"
copy /Y "%SRC%\services\firebase_draw_service.dart"                "%PROJECT%\lib\services\firebase_draw_service.dart"

echo    Done.

echo.
echo [3/5] Copying pubspec.yaml...
copy /Y "%~dp0flutter\pubspec.yaml" "%PROJECT%\pubspec.yaml"
echo    Done.

echo.
echo [4/5] Running flutter pub get...
cd /d "%PROJECT%"
call flutter pub get
echo    Done.

echo.
echo [5/5] All done!
echo.
echo ============================================
echo  Now run:  flutter run
echo ============================================
echo.
pause
