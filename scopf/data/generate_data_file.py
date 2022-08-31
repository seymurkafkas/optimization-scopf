from scopf.linalg.calculate_lodf import calculate_lodf
from .data_file_template import DATA_FILE_TEMPLATE
from scopf.linalg import calculate_lodf
from scopf.io import convert_lodf_to_ampl_data


def generate_data_file(data_file_file_paths):
    bus_data = open(data_file_file_paths["bus_file"], "r").read()
    line_data = open(data_file_file_paths["line_file"], "r").read()
    contingency_data = open(data_file_file_paths["contingency_file"], "r").read()
    cost_data = open(data_file_file_paths["cost_file"], "r").read()

    lodf_matrix = calculate_lodf(data_file_file_paths["line_file"],data_file_file_paths["bus_file"])
    lodf_data = convert_lodf_to_ampl_data(lodf_matrix)
    
    data_file_string = DATA_FILE_TEMPLATE.substitute(
        bus_data = bus_data,
        line_data = line_data,
        lodf_data = lodf_data, 
        contingency_data = contingency_data,
        cost_data = cost_data,)

    return data_file_string
    