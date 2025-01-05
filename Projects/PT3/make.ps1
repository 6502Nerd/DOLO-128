# Script to build PT3 player for Oric dflat
# Run this first before the make.ps1 in the 'software' folder
try {

$start = (Get-Date)

# Build pt3 player
Write-Output "Building PT3 Player"
./as65 "-ixnctl" "-oppt3.bin" ppt3.s
if ($LASTEXITCODE -gt 0) { throw }

# Copy files
Copy-Item ./*.bin ../../SDCARD/demos/pt3
Copy-Item ./tunes/*.* ../../SDCARD/demos/pt3
Copy-Item ./*.prg ../../SDCARD/demos/pt3

Write-Output ("Build completed in   :"+((Get-Date)-$start)+" seconds")

}
catch {
	Write-Output "COMPILATION ERRORS"
}

