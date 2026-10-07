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
Write-Host "MAIN DIRECTORY"
Write-Host "=========================================="
Write-Host $MAIN_DIR
Write-Host ""


# =========================================================
# 2. PROGRAM
# =========================================================

$meeko = "C:\Users\faizl\AppData\Roaming\mamba\envs\meeko"
$vina  = "C:\Users\faizl\OneDrive\Documents\KIMED\vina.exe"


# =========================================================
# 3. DIRECTORY
# =========================================================

$ligandDir   = Join-Path $MAIN_DIR "ligand"
$receptorDir = Join-Path $MAIN_DIR "receptor"
$configDir   = Join-Path $MAIN_DIR "config"
$resultsDir  = Join-Path $MAIN_DIR "results"

$outDir = Join-Path $resultsDir "out"
$logDir = Join-Path $resultsDir "log"


# =========================================================
# 4. MEEKO FUNCTIONS
# =========================================================

function preplig {
    micromamba run -p $meeko `
        python "$meeko\Scripts\mk_prepare_ligand.py" @args
}

function preprec {
    micromamba run -p $meeko `
        python "$meeko\Scripts\mk_prepare_receptor.py" @args
}


# =========================================================
# 5. FIND RAW INPUT
# =========================================================

$sdfFiles = Get-ChildItem `
    $MAIN_DIR `
    -Filter "*.sdf" `
    -File

$pdbFiles = Get-ChildItem `
    $MAIN_DIR `
    -Filter "*.pdb" `
    -File

# Cari PDBQT yang sudah tersedia langsung di MAIN_DIR
$existingPdbqtFiles = Get-ChildItem `
    $MAIN_DIR `
    -Filter "*.pdbqt" `
    -File


Write-Host "File SDF ditemukan  : $($sdfFiles.Count)"
Write-Host "File PDB ditemukan  : $($pdbFiles.Count)"
Write-Host "File PDBQT ditemukan: $($existingPdbqtFiles.Count)"
Write-Host ""


# =========================================================
# 6. CHECK RAW INPUT
# =========================================================

if ($sdfFiles.Count -eq 0) {

    Write-Host "ERROR: Tidak ada file .sdf di MAIN_DIR."
    exit
}


# =========================================================
# 7. CREATE DIRECTORIES
# =========================================================

New-Item `
    -ItemType Directory `
    -Path $ligandDir `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $receptorDir `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $configDir `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $outDir `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $logDir `
    -Force |
    Out-Null


# =========================================================
# 8. PREPARE LIGANDS
# =========================================================

Write-Host ""
Write-Host "=========================================="
Write-Host "PREPARASI LIGAND"
Write-Host "=========================================="


foreach ($f in $sdfFiles) {

    $output = Join-Path `
        $ligandDir `
        ($f.BaseName + ".pdbqt")


    if (Test-Path $output) {

        Write-Host "SKIP: $($f.Name)"
        continue
    }


    Write-Host "Preparing: $($f.Name)"


    preplig `
        -i $f.FullName `
        -o $output
}


# =========================================================
# 9. PREPARE RECEPTORS
# =========================================================

Write-Host ""
Write-Host "=========================================="
Write-Host "PREPARASI RECEPTOR"
Write-Host "=========================================="


if ($pdbFiles.Count -eq 0) {

    Write-Host ""
    Write-Host "Tidak ada file .pdb di $MAIN_DIR."
    Write-Host "Akan menggunakan receptor .pdbqt yang sudah tersedia."
    Write-Host ""

}
else {

    foreach ($f in $pdbFiles) {

        $output = Join-Path `
            $receptorDir `
            $f.BaseName

        $pdbqt = $output + ".pdbqt"


        # -------------------------------------------------
        # Jika PDBQT sudah ada → skip
        # -------------------------------------------------

        if (Test-Path $pdbqt) {

            Write-Host "SKIP: $($f.Name)"
            continue
        }


        Write-Host ""
        Write-Host "Preparing receptor:"
        Write-Host "  PDB = $($f.Name)"


        # -------------------------------------------------
        # Coba convert dengan Meeko
        # -------------------------------------------------

        preprec `
            -i $f.FullName `
            -o $output `
            -p


        # -------------------------------------------------
        # CHECK HASIL MEEKO
        # -------------------------------------------------

        if ($LASTEXITCODE -eq 0 -and (Test-Path $pdbqt)) {

            Write-Host "SUCCESS: $($pdbqt)"
        }
        else {

            Write-Host ""
            Write-Host "WARNING: Meeko gagal convert:"
            Write-Host "         $($f.Name)"
            Write-Host ""
            Write-Host "Receptor ini akan dilewati."
            Write-Host "Mencari PDBQT lain."
            Write-Host ""
        }
    }
}


# =========================================================
# 10. FIND AVAILABLE RECEPTOR PDBQT
# =========================================================

Write-Host ""
Write-Host "=========================================="
Write-Host "MENCARI RECEPTOR PDBQT"
Write-Host "=========================================="


# ---------------------------------------------------------
# Cari PDBQT hasil preparasi di receptor\
# ---------------------------------------------------------

$receptorPdbqtFiles = @(
    Get-ChildItem `
        $receptorDir `
        -Filter "*.pdbqt" `
        -File `
        -ErrorAction SilentlyContinue
)


# ---------------------------------------------------------
# Cari PDBQT yang sudah ada langsung di MAIN_DIR
# ---------------------------------------------------------

$mainPdbqtFiles = @(
    Get-ChildItem `
        $MAIN_DIR `
        -Filter "*.pdbqt" `
        -File `
        -ErrorAction SilentlyContinue
)


# ---------------------------------------------------------
# Gabungkan
# ---------------------------------------------------------

$receptors = @(
    $receptorPdbqtFiles
    $mainPdbqtFiles
) |
Sort-Object FullName -Unique


# ---------------------------------------------------------
# CHECK
# ---------------------------------------------------------

if ($receptors.Count -eq 0) {

    Write-Host ""
    Write-Host "ERROR: Tidak ada receptor PDBQT yang tersedia."
    Write-Host ""
    Write-Host "Tidak ada hasil Meeko dan tidak ada PDBQT lain."
    Write-Host "Docking tidak dapat dilanjutkan."
    exit
}


Write-Host ""
Write-Host "Receptor PDBQT tersedia: $($receptors.Count)"

foreach ($r in $receptors) {

    Write-Host " - $($r.FullName)"
}

# =========================================================
# 11. GRID BOX PARAMETERS
# =========================================================

$padding = 5.0

$num_modes = 20
$energy_range = 4
$exhaustiveness = 64
$cpu = 8


# =========================================================
# 12. CALCULATE GRID FOR EACH RECEPTOR
# =========================================================

Write-Host ""
Write-Host "=========================================="
Write-Host "CALCULATING GRID BOX"
Write-Host "=========================================="


foreach ($r in $receptors) {

    Write-Host ""
    Write-Host "Receptor: $($r.BaseName)"


    # -----------------------------------------------------
    # Read coordinates
    # -----------------------------------------------------

    $coords = @()


    Get-Content $r.FullName | ForEach-Object {

        $line = $_


        if (
            $line.StartsWith("ATOM") -or
            $line.StartsWith("HETATM")
        ) {

            try {

                $x = [double]$line.Substring(30,8)
                $y = [double]$line.Substring(38,8)
                $z = [double]$line.Substring(46,8)


                $coords += [PSCustomObject]@{
                    X = $x
                    Y = $y
                    Z = $z
                }
            }

            catch {
            }
        }
    }


    if ($coords.Count -eq 0) {

        Write-Host "ERROR: Tidak ada koordinat atom."
        Write-Host "Skip receptor: $($r.Name)"
        continue
    }


    # -----------------------------------------------------
    # Min / Max
    # -----------------------------------------------------

    $xmin = ($coords | Measure-Object X -Minimum).Minimum
    $xmax = ($coords | Measure-Object X -Maximum).Maximum

    $ymin = ($coords | Measure-Object Y -Minimum).Minimum
    $ymax = ($coords | Measure-Object Y -Maximum).Maximum

    $zmin = ($coords | Measure-Object Z -Minimum).Minimum
    $zmax = ($coords | Measure-Object Z -Maximum).Maximum


    # -----------------------------------------------------
    # Center
    # -----------------------------------------------------

    $center_x = ($xmin + $xmax) / 2
    $center_y = ($ymin + $ymax) / 2
    $center_z = ($zmin + $zmax) / 2


    # -----------------------------------------------------
    # Size
    # -----------------------------------------------------

    $size_x = ($xmax - $xmin) + (2 * $padding)
    $size_y = ($ymax - $ymin) + (2 * $padding)
    $size_z = ($zmax - $zmin) + (2 * $padding)


    # -----------------------------------------------------
    # Config filename
    # -----------------------------------------------------

    $config = Join-Path `
        $configDir `
        ($r.BaseName + "_config.txt")


    # -----------------------------------------------------
    # Write config
    # -----------------------------------------------------

@"
center_x = $("{0:F3}" -f $center_x)
center_y = $("{0:F3}" -f $center_y)
center_z = $("{0:F3}" -f $center_z)

size_x = $("{0:F3}" -f $size_x)
size_y = $("{0:F3}" -f $size_y)
size_z = $("{0:F3}" -f $size_z)

exhaustiveness = $exhaustiveness
num_modes = $num_modes
cpu = $cpu
energy_range = $energy_range
"@ | Set-Content $config


    # -----------------------------------------------------
    # Display
    # -----------------------------------------------------

    Write-Host ""
    Write-Host "Center:"
    Write-Host ("X = {0:F3}" -f $center_x)
    Write-Host ("Y = {0:F3}" -f $center_y)
    Write-Host ("Z = {0:F3}" -f $center_z)

    Write-Host ""

    Write-Host "Size:"
    Write-Host ("X = {0:F3}" -f $size_x)
    Write-Host ("Y = {0:F3}" -f $size_y)
    Write-Host ("Z = {0:F3}" -f $size_z)

    Write-Host ""
    Write-Host "Config: $config"
}


# =========================================================
# 13. FIND LIGANDS
# =========================================================

$ligands = Get-ChildItem `
    $ligandDir `
    -Filter "*.pdbqt" `
    -File


if ($ligands.Count -eq 0) {

    Write-Host ""
    Write-Host "ERROR: Tidak ada ligand PDBQT."
    exit
}


Write-Host ""
Write-Host "Ligand PDBQT ditemukan: $($ligands.Count)"

foreach ($l in $ligands) {

    Write-Host " - $($l.Name)"
}


# =========================================================
# 14. BATCH DOCKING
# =========================================================

Write-Host ""
Write-Host "=========================================="
Write-Host "AUTODOCK VINA"
Write-Host "=========================================="


foreach ($r in $receptors) {

    $receptorName = $r.BaseName


    # -----------------------------------------------------
    # Config untuk receptor ini
    # -----------------------------------------------------

    $config = Join-Path `
        $configDir `
        ($receptorName + "_config.txt")


    if (!(Test-Path $config)) {

        Write-Host ""
        Write-Host "ERROR: Config tidak ditemukan:"
        Write-Host $config

        continue
    }


    Write-Host ""
    Write-Host "=========================================="
    Write-Host "RECEPTOR: $receptorName"
    Write-Host "=========================================="


    foreach ($l in $ligands) {

        $ligandName = $l.BaseName


        # -------------------------------------------------
        # Output filename
        # -------------------------------------------------

        $outfile = Join-Path `
            $outDir `
            "${receptorName}__${ligandName}_out.pdbqt"


        $logfile = Join-Path `
            $logDir `
            "${receptorName}__${ligandName}_log.txt"


        # -------------------------------------------------
        # Skip existing docking
        # -------------------------------------------------

        if (Test-Path $outfile) {

            Write-Host "SKIP: $receptorName + $ligandName"
            continue
        }


        # -------------------------------------------------
        # Docking
        # -------------------------------------------------

        Write-Host ""
        Write-Host "Docking:"
        Write-Host "  Receptor = $receptorName"
        Write-Host "  Ligand   = $ligandName"


        & $vina `
            --receptor $r.FullName `
            --config $config `
            --ligand $l.FullName `
            --out $outfile `
            2>&1 |
            Tee-Object $logfile
    }
}


# =========================================================
# 15. DONE
# =========================================================

Write-Host ""
Write-Host "=========================================="
Write-Host "DOCKING SELESAI"
Write-Host "=========================================="

Write-Host ""
Write-Host "Receptor:"
Write-Host $receptorDir

Write-Host ""
Write-Host "Ligand:"
Write-Host $ligandDir

Write-Host ""
Write-Host "Config:"
Write-Host $configDir

Write-Host ""
Write-Host "Hasil:"
Write-Host $outDir

Write-Host ""
Write-Host "Log:"
Write-Host $logDir

Write-Host ""