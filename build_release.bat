@echo off
REM Build script for LivebookNx release

echo Building LivebookNx release...

REM Clean previous builds
if exist "_build" rmdir /s /q "_build"
if exist "rel\livebook_nx" rmdir /s /q "rel\livebook_nx"

REM Build the release
mix release livebook_nx

echo Release built successfully!
echo To run the release, use: rel\livebook_nx\bin\livebook_nx.bat start
