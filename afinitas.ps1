param(
    [Parameter(Mandatory=$true)]
    [string]$MAIN_DIR
)

# =========================================================
# 1. MAIN DIRECTORY
# =========================================================

$MAIN_DIR = (Resolve-Path $MAIN_DIR).Path

Write-Host ""
Write-Host "=========================================="
Write-Host "RANKING AFFINITY - MODEL 1"
Write-Host "=========================================="
Write-Host "MAIN DIRECTORY:"
Write-Host $MAIN_DIR
Write-Host ""


# =========================================================
# 2. DIRECTORY
# =========================================================

$logDir = Join-Path $MAIN_DIR "results\log"

$outputFile = Join-Path $MAIN_DIR "ranking_affinity_model1.txt"


# =========================================================
# 3. CHECK LOG DIRECTORY
# =========================================================

if (!(Test-Path $logDir)) {

    Write-Host "ERROR: Folder log tidak ditemukan:"
    Write-Host $logDir
    exit
}


# =========================================================
# 4. FIND LOG FILES
# =========================================================

$logFiles = Get-ChildItem `
    $logDir `
    -Filter "*_log.txt" `
    -File


if ($logFiles.Count -eq 0) {

    Write-Host ""
    Write-Host "ERROR: Tidak ada file *_log.txt di:"
    Write-Host $logDir
    exit
}


Write-Host "Log ditemukan: $($logFiles.Count)"
Write-Host ""


# =========================================================
# 5. EXTRACT MODEL 1 AFFINITY
# =========================================================

$results = @()

foreach ($log in $logFiles) {

    $lines = Get-Content $log.FullName

    $affinity = $null

    # -----------------------------------------------------
    # Cari tabel Vina
    # -----------------------------------------------------

    for ($i = 0; $i -lt $lines.Count; $i++) {

        if (
            $lines[$i] -match "mode\s*\|\s*affinity"
        ) {

            # Cari baris Model 1 setelah header
            for (
                $j = $i + 1;
                $j -lt $lines.Count;
                $j++
            ) {

                if (
                    $lines[$j] -match "^\s*1\s+(-?\d+(?:\.\d+)?)\s+"
                ) {

                    $affinity = [double]$Matches[1]

                    break
                }
            }

            break
        }
    }


    # -----------------------------------------------------
    # Jika affinity ditemukan
    # -----------------------------------------------------

    if ($null -ne $affinity) {

        # Contoh nama file:
        # quercetin_log.txt
        #
        # Yang diambil:
        # quercetin

        if (
            $log.BaseName -match "^(.+?)__(.+)_log$"
        ) {

            $receptorName = $Matches[1]
            $ligandName   = $Matches[2]

        }
        else {

            # Fallback jika format nama berbeda
            $receptorName = ""
            $ligandName   = $log.BaseName
        }


        $results += [PSCustomObject]@{

            Receptor = $receptorName
            Compound = $ligandName
            Affinity = $affinity
            File     = $log.Name
        }
    }

    else {

        Write-Host "WARNING: Model 1 tidak ditemukan:"
        Write-Host "         $($log.Name)"
    }
}


# =========================================================
# 6. CHECK RESULTS
# =========================================================

if ($results.Count -eq 0) {

    Write-Host ""
    Write-Host "ERROR: Tidak ada affinity Model 1 yang berhasil dibaca."
    exit
}


# =========================================================
# 7. SORT
# =========================================================

# Affinity semakin negatif = semakin tinggi ranking

$results = $results |
    Sort-Object Affinity


# =========================================================
# 8. CREATE OUTPUT
# =========================================================

$outputLines = @()

$outputLines += "RANKING DOCKING - MODEL 1"
$outputLines += "=============================================="
$outputLines += ""
$outputLines += "MAIN DIRECTORY : $MAIN_DIR"
$outputLines += "LOG DIRECTORY  : $logDir"
$outputLines += ""

$outputLines += (
    "{0,-8}{1,-35}{2,20}" -f `
    "Rank",
    "Nama Senyawa",
    "Affinity (kcal/mol)"
)

$outputLines += (
    "---------------------------------------------------------------"
)


# =========================================================
# 9. WRITE RANKING
# =========================================================

$rank = 1

foreach ($item in $results) {

    $outputLines += (
        "{0,-8}{1,-35}{2,20:F3}" -f `
        $rank,
        $item.Compound,
        $item.Affinity
    )

    $rank++
}


# =========================================================
# 10. SUMMARY
# =========================================================

$outputLines += ""
$outputLines += "---------------------------------------------------------------"
$outputLines += "Jumlah log ditemukan : $($logFiles.Count)"
$outputLines += "Berhasil dibaca      : $($results.Count)"


# =========================================================
# 11. SAVE TXT
# =========================================================

$outputLines |
    Set-Content `
        -Path $outputFile `
        -Encoding UTF8


# =========================================================
# 12. DISPLAY
# =========================================================

Write-Host ""

foreach ($line in $outputLines) {

    Write-Host $line
}

Write-Host ""
Write-Host "=========================================="
Write-Host "SELESAI"
Write-Host "=========================================="
Write-Host ""
Write-Host "Output:"
Write-Host $outputFile
Write-Host ""