# molecular-docking

Scripts for blind molecular docking of small-molecule compounds against a protein receptor (GPNMB ECD) with AutoDock Vina and Meeko, plus tools to rank results and check run-to-run reproducibility. Written for Windows (PowerShell + micromamba).

> **Note:** docking scores are computational estimates used to prioritise compounds. They are not experimental binding affinities and should be validated experimentally.

## Contents

| File | Purpose |
| --- | --- |
| `docking.ps1` | Full docking pipeline: Meeko ligand/receptor preparation, grid-box calculation, batch AutoDock Vina docking |
| `afinitas.ps1` | Reads Vina logs and ranks compounds by the affinity of model (mode) 1 |
| `RMSD.py` | Compares pose 1 of each compound across three independent docking runs (pairwise RMSD, CSV output) |

## Requirements

- Windows with PowerShell
- [Micromamba](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html) available in PowerShell (`micromamba shell init --shell powershell`, then restart the terminal)
- Python 3.9 - 3.11 (check the [Meeko PyPI page](https://pypi.org/project/meeko/) for the versions supported by the release you install)
- [AutoDock Vina](https://github.com/ccsb-scripps/AutoDock-Vina/releases) executable (`vina.exe`)
- Optional: PyMOL for visualisation

## 1. Install Meeko

Meeko prepares AutoDock input (ligand and receptor to PDBQT). It is developed by the Forli Lab at Scripps Research.

| Resource | Link |
| --- | --- |
| PyPI (`pip install`) | https://pypi.org/project/meeko/ |
| GitHub (source, issues) | https://github.com/forlilab/Meeko |
| Documentation | https://meeko.readthedocs.io |

Create an environment named `meeko` (the scripts call Meeko from this environment):

```powershell
micromamba create -n meeko python=3.10 -c conda-forge -y
micromamba activate meeko

# dependencies
micromamba install -c conda-forge numpy scipy rdkit -y

# Meeko (either one)
micromamba install -c conda-forge meeko -y
# or, if the conda package is not found or is outdated:
pip install meeko
```

Check the installation and find the environment path (needed later):

```powershell
python -c "import meeko; print('Meeko OK')"
micromamba env list
```

> Meeko does not generate 3D coordinates or assign protonation states. Provide ligands as 3D, correctly protonated SDF files, and a cleaned, protonated receptor PDB.

## 2. Install AutoDock Vina

Download the Windows executable from the [Vina releases page](https://github.com/ccsb-scripps/AutoDock-Vina/releases) and note its full path.

## 3. Clone this repository

```powershell
git clone https://github.com/faizalghi/molecular-docking.git
cd molecular-docking
```

## 4. Configure paths and parameters

Before the first run, edit the top of **`docking.ps1`**:

```powershell
$meeko = "C:\Users\<you>\AppData\Roaming\mamba\envs\meeko"   # path of the micromamba env (see: micromamba env list)
$vina  = "C:\path\to\vina.exe"
```

The script calls Meeko as `<env>\Scripts\mk_prepare_ligand.py` and `<env>\Scripts\mk_prepare_receptor.py` through `micromamba run -p`.

Docking parameters (section "Grid box parameters" of `docking.ps1`):

| Variable | Default | Meaning |
| --- | --- | --- |
| `$padding` | 5.0 | Å added on each side of the receptor bounding box |
| `$num_modes` | 20 | Poses kept per ligand |
| `$energy_range` | 4 | Max energy difference (kcal/mol) from the best pose |
| `$exhaustiveness` | 64 | Search effort |
| `$cpu` | 8 | CPU threads |

The grid box is computed automatically from the receptor PDBQT: its centre is the centre of the coordinate bounding box, and its size is the bounding-box extent plus `2 x padding` on each axis. The box therefore covers the **whole receptor (blind docking)**.

## 5. Usage

### 5.1 Input folder (one folder per run)

```
Senyawa_uji_batch1_meeko/
├── GPNMB ECD.pdb        # receptor (or an existing receptor .pdbqt)
├── compound_A.sdf       # one SDF per test compound (3D, protonated)
├── compound_B.sdf
└── ...
```

Raw inputs go directly in the main folder. The scripts create the other folders.

### 5.2 Run docking

```powershell
.\docking.ps1 "C:\path\to\Senyawa_uji"
```

If PowerShell blocks the script:

```powershell
powershell -ExecutionPolicy Bypass -File .\docking.ps1 -MAIN_DIR "C:\path\to\Senyawa_uji"
```

What the script does:

1. Converts every `.sdf` to `ligand\<name>.pdbqt` with `mk_prepare_ligand.py`.
2. Converts every `.pdb` to `receptor\<name>.pdbqt` with `mk_prepare_receptor.py -p`. If Meeko fails, or no `.pdb` is present, it falls back to any `.pdbqt` already in the main folder.
3. Writes `config\<receptor>_config.txt` (box centre/size and Vina settings).
4. Docks every ligand against every receptor with Vina.
5. Skips any ligand, receptor or docking result that already exists, so an interrupted run can be resumed.

Generated structure:

```
Senyawa_uji_batch1_meeko/
├── ligand/      # ligand PDBQT
├── receptor/    # receptor PDBQT
├── config/      # <receptor>_config.txt
└── results/
    ├── out/     # <receptor>__<ligand>_out.pdbqt  (docked poses)
    └── log/     # <receptor>__<ligand>_log.txt    (Vina logs)
```

### 5.3 Rank by affinity

```powershell
.\afinitas.ps1 -MAIN_DIR "C:\path\to\Senyawa_uji_batch1_meeko"
```

Reads `results\log\*_log.txt`, takes the affinity of model 1 from each Vina table, sorts from most negative (best) to least negative, and writes `ranking_affinity_model1.txt` in the main folder (columns: rank, compound, affinity in kcal/mol).

### 5.4 Three independent runs and RMSD

The docking script does not set a fixed Vina seed, so repeating the run on the same inputs gives independent runs. Prepare three folders with identical inputs (for example `Senyawa_uji_batch1_meeko`, `batch2`, `batch3`) and run `docking.ps1` on each.

Then edit `MAIN_DIR_1`, `MAIN_DIR_2` and `MAIN_DIR_3` at the top of `RMSD.py` so they point to the three `results\out` folders, and run:

```powershell
micromamba run -n meeko python RMSD.py
```

`RMSD.py` needs only `numpy`. For every file name present in all three folders it:

- reads model 1 and keeps heavy atoms only (hydrogens are ignored),
- checks that the number, names and order of heavy atoms are identical across runs,
- computes pairwise RMSD (run 1-2, 1-3, 2-3) and their mean,
- writes `RMSD_3_running.csv` into `MAIN_DIR_1`.

CSV columns: `Compound; Heavy_Atoms; RMSD_Run1_Run2_A; RMSD_Run1_Run3_A; RMSD_Run2_Run3_A; Mean_Pairwise_RMSD_A; Status`. The delimiter is `;` and the decimal separator is `,`, so the file opens directly in Excel with Indonesian/European regional settings.

## Notes and limitations

- **RMSD.py aligns poses before measuring (Kabsch superposition).** The value therefore reflects how similar the ligand *conformations* are across runs, not whether the poses sit at the same place on the receptor. Two poses with the same shape but on opposite sides of the protein give an RMSD of about 0. For blind docking, also report an in-place RMSD (no alignment) or the distance between pose centroids.
- **Ranking by raw Vina affinity** (`afinitas.ps1`) does not correct for ligand size, and in blind docking a good score does not guarantee the pose is at the intended site. Treat the ranking as a first-pass prioritisation.
- Compound names in the RMSD CSV are derived from the file name by removing the `GPNMB ECD__` prefix and the `_out.pdbqt` suffix. A different receptor name leaves the prefix in place, and the current suffix trimming leaves a trailing `_` on each name.
- The scripts contain machine-specific absolute paths (`$meeko`, `$vina`, `MAIN_DIR_1..3`). Edit them before running on another computer.

## Reproducibility checklist

Record with every run:

- Software versions: `micromamba env export -n meeko > environment.yml` and the Vina version (`vina --version`)
- Docking parameters from `config\*_config.txt`
- Number of independent runs and the RMSD CSV
- Receptor and ligand preparation settings (protonation pH, cleaning steps, Meeko options)

## Citation

If you use this repository, please also cite the underlying tools:

- **AutoDock Vina:** Trott, O. & Olson, A. J. *J. Comput. Chem.* 31, 455-461 (2010); Eberhardt, J., Santos-Martins, D., Tillack, A. F. & Forli, S. *J. Chem. Inf. Model.* 61, 3891-3898 (2021).
- **Meeko:** see https://github.com/forlilab/Meeko and https://meeko.readthedocs.io for the current citation.

## License

Add a license (for example MIT) to this repository.

## Contact

Maintained by [@faizalghi](https://github.com/faizalghi).
