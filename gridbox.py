receptor = r"receptor\GPNMB ECD.pdbqt"
output = "config.txt"

padding = 5.0
num_modes = 20
energy_range = 4
exhaustiveness = 64
cpu = 8

coords = []

with open(receptor, "r") as f:
    for line in f:
        if line.startswith(("ATOM", "HETATM")):
            try:
                x = float(line[30:38])
                y = float(line[38:46])
                z = float(line[46:54])
                coords.append((x, y, z))
            except ValueError:
                pass

if not coords:
    raise ValueError("Tidak ditemukan koordinat atom pada file receptor.")

xmin = min(x for x, y, z in coords)
xmax = max(x for x, y, z in coords)

ymin = min(y for x, y, z in coords)
ymax = max(y for x, y, z in coords)

zmin = min(z for x, y, z in coords)
zmax = max(z for x, y, z in coords)

center_x = (xmin + xmax) / 2
center_y = (ymin + ymax) / 2
center_z = (zmin + zmax) / 2

size_x = (xmax - xmin) + (2 * padding)
size_y = (ymax - ymin) + (2 * padding)
size_z = (zmax - zmin) + (2 * padding)

with open(output, "w") as f:
    f.write("receptor = " + receptor + "\n\n")

    f.write("center_x = {:.3f}\n".format(center_x))
    f.write("center_y = {:.3f}\n".format(center_y))
    f.write("center_z = {:.3f}\n\n".format(center_z))

    f.write("size_x = {:.3f}\n".format(size_x))
    f.write("size_y = {:.3f}\n".format(size_y))
    f.write("size_z = {:.3f}\n\n".format(size_z))

    f.write("exhaustiveness = " + str(exhaustiveness) + "\n")
    f.write("num_modes = " + str(num_modes) + "\n")
    f.write("cpu = " + str(cpu) + "\n")
    f.write("energy_range = " + str(energy_range) + "\n")
    

print("Grid box berhasil dihitung.")
print()
print("Center: {:.3f}, {:.3f}, {:.3f}".format(
    center_x, center_y, center_z
))
print("Size: {:.3f}, {:.3f}, {:.3f}".format(
    size_x, size_y, size_z
))
print("Config: " + output)