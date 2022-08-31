from amplpy import AMPL
import logging
from pathlib import Path
from tempfile import NamedTemporaryFile
import scopf.model
from scopf.data import generate_data_file
from os import remove


FILE_PATH_MODEL = Path(scopf.model.__file__).parent.joinpath("model.mod")


def solve_scopf_problem(file_path_bus_data, file_path_line_data, file_path_cost_data, file_path_contingency_data):
    try:
        data_file_file_paths = {
        "bus_file":file_path_bus_data,
        "line_file" : file_path_line_data,
        "cost_file" : file_path_cost_data,
        "contingency_file" : file_path_contingency_data,
        }

        data_file_contents = generate_data_file(data_file_file_paths)
        ampl = AMPL()
        ampl.read(FILE_PATH_MODEL)
        temp_data_file = NamedTemporaryFile("w",delete = False)
        temp_data_file.write(data_file_contents)
        ampl.read_data(temp_data_file.name)
        ampl.solve()
    except Exception as e:
        print(e)
        logging.error(e)
    finally:
        if temp_data_file is not None:
            temp_data_file.close()
            remove(temp_data_file.name)
