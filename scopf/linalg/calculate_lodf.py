import numpy
from numpy.linalg import inv
from functools import reduce
from scopf.io import process_line_and_bus_file


def calculate_lodf(
    line_filename,
    bus_filename,
):
    (slack_bus, line_data, bus_data) = process_line_and_bus_file(
        line_filename, bus_filename
    )

    bus_count = len(bus_data)
    line_count = len(line_data)

    line_power_matrix = numpy.zeros((line_count, bus_count), dtype=float)

    for i in range(line_count):
        bus_from = int(line_data[i]["line_from"]) - 1
        bus_to = int(line_data[i]["line_to"]) - 1
        admittance = 1 / float(line_data[i]["line_x"])
        line_power_matrix[i][bus_from] = admittance
        line_power_matrix[i][bus_to] = -admittance

    bus_power_matrix = numpy.zeros((bus_count, bus_count), dtype=float)

    for i in range(bus_count):
        incident_lines = filter(
            lambda line: (
                line["line_from"] == str(i + 1) or line["line_to"] == str(i + 1)
            ),
            line_data,
        )

        sum_of_admittances = reduce(
            lambda acc, current: (acc + (1 / float(current["line_x"]))),
            incident_lines,
            0.0,
        )

        diagonal_term = sum_of_admittances
        bus_power_matrix[i, i] = diagonal_term

    for line in line_data:
        line_from = int(line["line_from"])
        line_to = int(line["line_to"])
        current_admittance = 1 / float(line["line_x"])
        bus_power_matrix[line_from - 1][line_to - 1] -= current_admittance
        bus_power_matrix[line_to - 1][line_from - 1] -= current_admittance

    slack_deleted_line_power_matrix = numpy.delete(
        line_power_matrix, int(slack_bus) - 1, 1
    )
    slack_deleted_bus_power_matrix = numpy.delete(
        bus_power_matrix, int(slack_bus) - 1, 1
    )
    slack_deleted_bus_power_matrix = numpy.delete(
        slack_deleted_bus_power_matrix, int(slack_bus) - 1, 0
    )
    ptdf_matrix = numpy.matmul(
        slack_deleted_line_power_matrix, inv(slack_deleted_bus_power_matrix)
    )

    zero_column_for_slack = numpy.zeros((line_count, 1))
    ptdf_matrix = numpy.hstack(
        (
            ptdf_matrix[:, : int(slack_bus) - 1],
            zero_column_for_slack,
            ptdf_matrix[:, int(slack_bus) - 1 :],
        )
    )
    line_ptdf_matrix = numpy.zeros((line_count, line_count))

    for i in range(line_count):
        for j in range(line_count):
            line = line_data[j]
            line_from = int(line["line_from"]) - 1
            line_to = int(line["line_to"]) - 1
            line_ptdf_matrix[i][j] = ptdf_matrix[i][line_from] + ptdf_matrix[i][line_to]

    lodf_matrix = numpy.zeros((line_count, line_count))

    for i in range(line_count):
        for j in range(line_count):
            if i == j:
                lodf_matrix[i][j] = -1
            else:
                lodf_matrix[i][j] = line_ptdf_matrix[i][j] / (
                    1 - (line_ptdf_matrix[j][j])
                )
    return lodf_matrix