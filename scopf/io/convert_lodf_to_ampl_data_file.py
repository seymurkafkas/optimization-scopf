import numpy


def convert_lodf_to_ampl_data_file(lodf_matrix, output_file_path):
    with open(output_file_path, "w") as f:
        for iy, ix in numpy.ndindex(lodf_matrix.shape):
            f.write(f"{iy + 1} {ix + 1} {lodf_matrix[iy][ix]}\n")
    return
