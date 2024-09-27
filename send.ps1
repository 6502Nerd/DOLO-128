<#

Custom file transfer protocol

Protocol overview:

Block structure:
[b] 1 byte block number
[s] 1 byte payload size between 1-250
[p] [s] bytes payload
[x] 250-[s] bytes padding (random)
[c] 1 byte checksum  simple sum of all payload including padding bytes
Blocks are always 253 bytes long.

Metadata block indicated by [b]==0
[s] is ignored
[f] bytes zero terminated filename
[d] bytes directory name(s)
    each directory name zero terminated until two zeros found
[x] bytes padding - ignored

Data block indicated by [b]!=0
[s] is used
[x] bytes padding - ignored

Block transmission protocol
1. PC sends SOH
2, HBC sends ACK
3. PC sends a block
4. HBC returns NAK if block bad -> PC goes to step 3 to re-send
5. HBC returns ACK if block good -> PC goes to step 1 for next block
6. If no more blocks PC sends ETB to indicate end of transmission
7. HBC returns ACK.


#>


#<#

param(
    # Which COM port
    [Parameter(Mandatory, Position = 0)] [string]$comport,
    # Filename on PC
    [Parameter(Mandatory, Position = 1)] [string]$fname,
    # hbc directory path
    [Parameter(Position = 2)] [string]$dirpath
)

try {

# Some variables
$SOH=1
$ACK=6
$NACK=21
$ETB=23

# Set the transmission data block size
$dataSize = 250
# Allocate array for the block including meta-data
# [0]=block #
# [1]=payload size
# [2..251]=data block
# [252]=checksum byte (twos complement of the sum)

$dataBlock = [byte[]]::new($dataSize+3)

$blockSize = $dataBlock.length
# global block number
$blockNumber = 0
# global done flag
$finished = 0
# Position in source file
$srcPos = 0

# Open the serial port
$port = new-Object System.IO.Ports.SerialPort $comport,19200,None,8,one
$port.open()

# Read the file into memory
$binaryData = Get-Content -Path $fname -Encoding byte


# Send end of transmission and wait for ACK
function send-etb {
    Write-Host "Ending transmission.."
    # Send SOH until ACK received
    do {
        $port.Write([byte[]]($ETB),0,1)
    } until ($port.ReadByte() -eq $ACK)
}

# Send a pre-formed block until ACK received
function send-block {
    Write-Host "Waiting to start.."
    # Send SOH until ACK received
    do {
        $port.Write([byte[]]($SOH),0,1)
    } until ($port.ReadByte() -eq $ACK)

    Write-Host "Sending block" $datablock[0]
    # Ok, now send block until ACK received
    do {
        for($i=0; $i -lt $dataBlock.length; $i++) {
            $port.Write([byte[]]($dataBlock[$i]),0,1)
        }
        Write-Host "Waiting for ACK"
    } until ($port.ReadByte() -eq $ACK)
    Write-Host "Block acknowledged"
}

# Add checksum after payload
function make-checksum {
    # initialise checksum byte to 0
    $cs = 0
    # calculate sum of bytes before checksum byte
    for ($i=0; $i -lt ($blockSize-1); $i++) {
        $cs += $datablock[$i]
    }
    # checksum is twos complement of the low byte
    $dataBlock[$blockSize-1] = (256 - ($cs % 256)) % 256
}

# Form block 0
function make-block0 {
    # initialise block number and payload size
    $blockNumber = 0
    $dataBlock[0] = $blockNumber
    $dataBlock[1] = 0

    # find the start position of filename
    for ($i=$fname.length-1; ($i -ge 0) -and ($fname[$i] -NotIn ('\','/')); $i--) {

    }

    # stuff in the filename from pos 2
    $p = 2
    for ($i=$i+1; $i -lt $fname.length; $i++) {
        $dataBlock[$p++]=$fname[$i]
    }
    $dataBlock[$p++]=0

    # stuff in each directory in destination
    for ($i=0; $i -lt $dirpath.length; $i++) {
        $ch=$dirpath[$i]
        if ($ch -in ('\','/')) {
            $ch=0
        }
        $dataBlock[$p++]=$ch
    }
    # ensure double 0 after last directory
    $dataBlock[$p++]=0
    $dataBlock[$p++]=0
    # now add the checksum byte
    make-checksum
}

# Form block n
function make-blockn {
    # initialise block number
    $dataBlock[0] = ($blockNumber % 256)
    if ($dataBlock[0] -eq 0) { $dataBlock[0] = 1}
    $payload = 0
    
    # stuff in payload from position 2
    for ($i=2; $i -lt ($blockSize-1); $i++) {
        if ($script:srcPos -lt $binaryData.length) {
            $datablock[$i] = $binaryData[$script:srcPos++]
            $payload++
        } else {
            $script:finished = 1
        }
    }

    # set payload size
    $dataBlock[1] = $payload

    # now add the checksum byte
    make-checksum

    Write-Host $srcPos  $binaryData.length
}

make-block0
send-block
do {
    $blockNumber++
    make-blockn
    send-block
} until ($script:finished -eq 1)
send-etb

}

finally {
    if ($port -ne $null) {
        $port.close()
    }
}