@echo off
setlocal
set hvigor_project_path=%~dp0
set hvigor_wrapper_home=%hvigor_project_path%\hvigor
set hvigor_home=%HVIGOR_HOME%
if "%hvigor_home%"=="" (
  for /d %%d in ("%USERPROFILE%\.hvigor\project_caches") do (
    set hvigor_home=%%d
  )
)
if "%hvigor_home%"=="" (
  for /d %%d in ("%LOCALAPPDATA%\Huawei\DevEcoStudio\*\plugins\*") do (
    set hvigor_home=%%d
  )
)
if exist "%hvigor_wrapper_home%\hvigor-wrapper.js" (
  node "%hvigor_wrapper_home%\hvigor-wrapper.js" %*
  exit /b %ERRORLEVEL%
)
echo [hvigor] hvigor-wrapper.js not found. Please open this project with DevEco Studio.
exit /b 1
