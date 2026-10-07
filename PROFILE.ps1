$meeko = "C:\Users\faizl\AppData\Roaming\mamba\envs\meeko"

$vina = "C:\Users\faizl\OneDrive\Documents\KIMED\vina.exe"

$docking = "C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\docking.ps1"

$autodock = "C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\autodock.ps1"

$ranking = "C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\afinitas.ps1"

function preplig { python "$env:CONDA_PREFIX\Scripts\mk_prepare_ligand.py" @args }

function preprec { python "$env:CONDA_PREFIX\Scripts\mk_prepare_receptor.py" @args }

function batchlig {
    mkdir ligand -Force | Out-Null
    Get-ChildItem *.sdf | % {
        preplig -i $_.FullName -o "ligand\$($_.BaseName).pdbqt"
    }
}

function batchrec {
    mkdir receptor -Force | Out-Null
    Get-ChildItem *.pdb | % {
        preprec -i $_.FullName -o "receptor\$($_.BaseName)" -p 
    }
}

function batchvina {
    $ligands = Join-Path C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\senyawa_uji_batch_1\ "ligand"
    $results = Join-Path C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\senyawa_uji_batch_1\ "results"

    mkdir $results -Force | Out-Null
    cd C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\senyawa_uji_batch_1

    foreach ($f in Get-ChildItem "$ligands\*.pdbqt") {
        $b = $f.BaseName
        $outdir = "$results\out"
        $logdir = "$results\log"    

        mkdir $outdir -Force | Out-Null
        mkdir $logdir -Force | Out-Null

        Write-Host "Processing ligand: $b"

        & $vina `
            --receptor ".\receptor\GPNMB ECD.pdbqt" `
            --config ".\config.txt" `
            --ligand $f.FullName `
            --out "$outdir\${b}_out.pdbqt" `
            2>&1 | Tee-Object "$logdir\${b}_log.txt"
    }
}