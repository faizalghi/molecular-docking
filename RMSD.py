from pathlib import Path
import csv
import math
import numpy as np


# ============================================================
# 1. MAIN DIRECTORY - 3 RUNNING
# ============================================================

MAIN_DIR_1 = Path(
    r"C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\Senyawa_uji_batch1_meeko\results\out"
)

MAIN_DIR_2 = Path(
    r"C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\Senyawa_uji_batch2_meeko\results\out"
)

MAIN_DIR_3 = Path(
    r"C:\Users\faizl\OneDrive\Documents\KIMED\KTIUNDIP\Senyawa_uji_batch3_meeko\results\out"
)


# ============================================================
# 2. OUTPUT
# ============================================================

OUTPUT_FILE = MAIN_DIR_1 / "RMSD_3_running.csv"


# ============================================================
# 3. PARSE ATOM PDBQT
# ============================================================

def parse_atom_line(line):

    try:
        atom_name = line[12:16].strip()

        x = float(line[30:38])
        y = float(line[38:46])
        z = float(line[46:54])

        atom_type = line[77:79].strip()

        if not atom_type:
            atom_type = atom_name

        atom_type_upper = atom_type.upper()
        atom_name_upper = atom_name.upper()

        is_hydrogen = (
            atom_type_upper.startswith("H")
            or atom_name_upper.startswith("H")
        )

        if is_hydrogen:
            return None

        return {
            "name": atom_name,
            "type": atom_type,
            "coord": [x, y, z]
        }

    except (ValueError, IndexError):
        return None


# ============================================================
# 4. BACA MODEL 1
# ============================================================

def read_pose1_heavy_atoms(filepath):

    atoms = []

    in_model_1 = False
    found_model = False

    with open(
        filepath,
        "r",
        encoding="utf-8",
        errors="ignore"
    ) as f:

        for line in f:

            # MODEL
            if line.startswith("MODEL"):

                model_number = line[5:].strip()

                if model_number == "1":
                    in_model_1 = True
                    found_model = True
                    continue

                elif found_model:
                    break

            # File tidak memiliki MODEL
            if not found_model:

                if line.startswith(("ATOM", "HETATM")):

                    atom = parse_atom_line(line)

                    if atom is not None:
                        atoms.append(atom)

                continue

            # Sedang membaca MODEL 1
            if in_model_1:

                if line.startswith(("ATOM", "HETATM")):

                    atom = parse_atom_line(line)

                    if atom is not None:
                        atoms.append(atom)

                elif line.startswith("ENDMDL"):

                    break

    return atoms


# ============================================================
# 5. KABSCH RMSD
# ============================================================

def calculate_rmsd(coords_a, coords_b):

    A = np.asarray(coords_a, dtype=float)
    B = np.asarray(coords_b, dtype=float)

    if A.shape != B.shape:

        message = (
            "Jumlah atom berbeda: "
            + str(A.shape[0])
            + " vs "
            + str(B.shape[0])
        )

        raise ValueError(message)

    if len(A) == 0:
        raise ValueError("Tidak ada heavy atom.")

    # Center
    centroid_A = np.mean(A, axis=0)
    centroid_B = np.mean(B, axis=0)

    A_centered = A - centroid_A
    B_centered = B - centroid_B

    # Covariance matrix
    H = np.dot(A_centered.T, B_centered)

    # SVD
    U, S, Vt = np.linalg.svd(H)

    # Hindari refleksi
    d = np.linalg.det(
        np.dot(Vt.T, U.T)
    )

    if d < 0:
        Vt[-1, :] *= -1

    # Rotation matrix
    R = np.dot(
        Vt.T,
        U.T
    )

    # Rotate A
    A_rotated = np.dot(
        A_centered,
        R.T
    )

    # RMSD
    diff = A_rotated - B_centered

    squared_distances = np.sum(
        diff ** 2,
        axis=1
    )

    rmsd = math.sqrt(
        np.mean(squared_distances)
    )

    return rmsd


# ============================================================
# 6. CEK DIRECTORY
# ============================================================

directories = [
    MAIN_DIR_1,
    MAIN_DIR_2,
    MAIN_DIR_3
]

for i, directory in enumerate(
    directories,
    start=1
):

    if not directory.exists():

        raise FileNotFoundError(
            "MAIN_DIR Run "
            + str(i)
            + " tidak ditemukan:\n"
            + str(directory)
        )


# ============================================================
# 7. CARI FILE PDBQT
# ============================================================

files_1 = {
    f.name: f
    for f in MAIN_DIR_1.glob("*.pdbqt")
}

files_2 = {
    f.name: f
    for f in MAIN_DIR_2.glob("*.pdbqt")
}

files_3 = {
    f.name: f
    for f in MAIN_DIR_3.glob("*.pdbqt")
}


common_files = sorted(
    set(files_1.keys())
    & set(files_2.keys())
    & set(files_3.keys())
)


print()
print("=" * 70)
print("RMSD ANALYSIS - 3 INDEPENDENT DOCKING RUNS")
print("=" * 70)

print(
    "Run 1 files : "
    + str(len(files_1))
)

print(
    "Run 2 files : "
    + str(len(files_2))
)

print(
    "Run 3 files : "
    + str(len(files_3))
)

print(
    "Common files: "
    + str(len(common_files))
)

print()


# ============================================================
# 8. HITUNG RMSD
# ============================================================

results = []


for index, filename in enumerate(
    common_files,
    start=1
):

    print(
        "["
        + str(index)
        + "/"
        + str(len(common_files))
        + "] "
        + filename
    )

    file_1 = files_1[filename]
    file_2 = files_2[filename]
    file_3 = files_3[filename]

    compound = filename

    if compound.startswith("GPNMB ECD__"):

        compound = compound.replace(
            "GPNMB ECD__",
            "",
            1
        )

    if compound.endswith("_out.pdbqt"):

        compound = compound[:-9]

    try:

        atoms_1 = read_pose1_heavy_atoms(file_1)
        atoms_2 = read_pose1_heavy_atoms(file_2)
        atoms_3 = read_pose1_heavy_atoms(file_3)

        coords_1 = [
            atom["coord"]
            for atom in atoms_1
        ]

        coords_2 = [
            atom["coord"]
            for atom in atoms_2
        ]

        coords_3 = [
            atom["coord"]
            for atom in atoms_3
        ]

        # ----------------------------------------------------
        # Jumlah heavy atom
        # ----------------------------------------------------

        n1 = len(coords_1)
        n2 = len(coords_2)
        n3 = len(coords_3)

        if not (n1 == n2 == n3):

            raise ValueError(
                "Jumlah heavy atom berbeda: "
                + "Run1="
                + str(n1)
                + ", Run2="
                + str(n2)
                + ", Run3="
                + str(n3)
            )

        # ----------------------------------------------------
        # Identitas dan urutan atom
        # ----------------------------------------------------

        atom_keys_1 = [
            (atom["name"], atom["type"])
            for atom in atoms_1
        ]

        atom_keys_2 = [
            (atom["name"], atom["type"])
            for atom in atoms_2
        ]

        atom_keys_3 = [
            (atom["name"], atom["type"])
            for atom in atoms_3
        ]

        if not (
            atom_keys_1
            == atom_keys_2
            == atom_keys_3
        ):

            raise ValueError(
                "Identitas atau urutan heavy atom berbeda."
            )

        # ----------------------------------------------------
        # RMSD pairwise
        # ----------------------------------------------------

        rmsd_1_2 = calculate_rmsd(
            coords_1,
            coords_2
        )

        rmsd_1_3 = calculate_rmsd(
            coords_1,
            coords_3
        )

        rmsd_2_3 = calculate_rmsd(
            coords_2,
            coords_3
        )

        # ----------------------------------------------------
        # Mean pairwise RMSD
        # ----------------------------------------------------

        mean_rmsd = (
            rmsd_1_2
            + rmsd_1_3
            + rmsd_2_3
        ) / 3.0

        results.append([
    compound,
    n1,
    format(rmsd_1_2, ".5f"),
    format(rmsd_1_3, ".5f"),
    format(rmsd_2_3, ".5f"),
    format(mean_rmsd, ".5f"),
    "OK"
])

        print(
            "    RMSD 1-2 : "
            + format(rmsd_1_2, ".3f")
            + " A"
        )

        print(
            "    RMSD 1-3 : "
            + format(rmsd_1_3, ".3f")
            + " A"
        )

        print(
            "    RMSD 2-3 : "
            + format(rmsd_2_3, ".3f")
            + " A"
        )

        print(
            "    Mean     : "
            + format(mean_rmsd, ".3f")
            + " A"
        )

    except Exception as e:

        print(
            "    ERROR: "
            + str(e)
        )

        results.append([
            compound,
            "",
            "",
            "",
            "",
            "",
            "ERROR: " + str(e)
        ])


## ============================================================
# 9. SIMPAN CSV
# ============================================================

try:
    with open(
        str(OUTPUT_FILE),
        "w",
        newline="",
        encoding="utf-8-sig"
    ) as f:

        writer = csv.writer(
            f,
            delimiter=";",
            quoting=csv.QUOTE_MINIMAL
        )

        writer.writerow([
            "Compound",
            "Heavy_Atoms",
            "RMSD_Run1_Run2_A",
            "RMSD_Run1_Run3_A",
            "RMSD_Run2_Run3_A",
            "Mean_Pairwise_RMSD_A",
            "Status"
        ])

        for row in results:
            writer.writerow([
                row[0],
                row[1],
                str(row[2]).replace(".", ","),
                str(row[3]).replace(".", ","),
                str(row[4]).replace(".", ","),
                str(row[5]).replace(".", ","),
                row[6]
            ])

except Exception as e:
    print()
    print("GAGAL MENYIMPAN CSV")
    print("Error:", str(e))
    print("Lokasi output:")
    print(str(OUTPUT_FILE))
    raise


# ============================================================
# 10. SELESAI
# ============================================================

print()
print("=" * 70)
print("SELESAI")
print("=" * 70)
print("Hasil disimpan di:")
print(str(OUTPUT_FILE))
print("=" * 70)