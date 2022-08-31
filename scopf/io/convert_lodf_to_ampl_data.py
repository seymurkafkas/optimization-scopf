import numpy


def convert_lodf_to_ampl_data(lodf_matrix):
    lodf_partial_strings = []
    for iy, ix in numpy.ndindex(lodf_matrix.shape):
        lodf_partial_strings.append(f"{iy + 1} {ix + 1} {lodf_matrix[iy][ix]}\n")

    lodf_data_for_ampl = "".join(lodf_partial_strings)
    return lodf_data_for_ampl
